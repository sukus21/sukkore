import os
import sys
import math

verbose = True

class Module:
    def __init__(self, title, author, copyright):
        self.title = title
        self.author = author
        self.copyright = copyright
        
        self.songs = []
        self.waveforms = []

    def add_song(self, song):
        self.songs.append(song)

class Song:
    def __init__(self, title, rows_per_beat, rows_per_measure, speed, rows_per_segment):
        self.title = title
        
        self.rows_per_beat = rows_per_beat
        self.rows_per_measure = rows_per_measure
        self.speed = speed
        self.rows_per_segment = rows_per_segment

        self.patterns = [[None] * 256, [None] * 256, [None] * 256, [None] * 256]
        self.sections = []
    
    def add_pattern(self, channel, pattern_id, pattern):
        if verbose:
            print(f"Retrieved pattern {pattern_id} of channel {channel}!")
        assert(self.patterns[channel][pattern_id] == None)
        self.patterns[channel][pattern_id] = pattern
    
    def add_section(self, section):
        self.sections.append(section)
    
    def emit_yeller_code(self):
        out = b"\0" # Start with a no-op for now to keep things consistent.

        fpr = self.speed / 16

        last_event_frame = 0

        effect_state = [
            {
                "envelope": 0xF0,
                "duty": 0x01,
            },
            {
                "envelope": 0xF0,
                "duty": 0x01,
            },
            {
                "envelope": 0xF0,
                "duty": 0x01,
            },
            {
                "envelope": 0xF0,
                "duty": 0x01,
            },
        ]

        section_starts = []

        for section_i, section in enumerate(self.sections):
            section_row_offset = section_i * self.rows_per_segment

            patterns = [self.patterns[i][section[i]] for i in range(4)]
            patterns_progress = [0] * 4

            section_starts += [len(out)]

            while True:
                curr_event = None
                curr_channel = None
                for pattern_i, pattern in enumerate(patterns):
                    pattern_progress = patterns_progress[pattern_i]

                    if pattern == None:
                        continue
                    if pattern_progress == len(pattern.events):
                        continue
                    
                    next_event_on_channel = pattern.events[pattern_progress]
                    if curr_event == None or next_event_on_channel.time < curr_event.time:
                        curr_event = next_event_on_channel
                        curr_channel = pattern_i
                if curr_channel == None:
                    break
                patterns_progress[curr_channel] += 1

                pattern = patterns[curr_channel]

                if curr_event.get_size(curr_channel) != 0:
                    event_frame = math.floor(fpr * (curr_event.time + section_row_offset))
                    event_delay = event_frame - last_event_frame
                    last_event_frame = event_frame
                    out += event_delay.to_bytes(1, byteorder="little")

                event_code = curr_event.emit({
                    "song": self,
                    "channel": curr_channel,
                    "next_byte_index": len(out),
                    "effect_state": effect_state[curr_channel],
                    "section_starts": section_starts,
                })
                assert(len(event_code) == curr_event.get_size(curr_channel))
                out += event_code
        
        return out

class Pattern:
    def __init__(self):
        self.events = []
    
    def add_event(self, event):
        self.events.append(event)

class Event:
    def __init__(self, time):
        self.time = time
    
    def emit(self, emit_state):
        assert(False)
    
    def get_size(self, channel):
        assert(False)

class NoteEvent(Event):
    def __init__(self, time, note):
        super().__init__(time)

        self.note = note
    
    def emit(self, emit_state):
        channel = emit_state["channel"]

        if channel == 0 or channel == 1:
            frequency = 440 * math.pow(2, (self.note - 34) / 12)
            period_value = 2048 - math.floor(131072 / frequency)

            duty_time_byte = (emit_state["effect_state"]["duty"] << 6).to_bytes(1, byteorder="little")

            envelope_byte = emit_state["effect_state"]["envelope"].to_bytes(1, byteorder="little")

            period_value_low_byte = (period_value % 256).to_bytes(1, byteorder="little")
            period_value_high_byte = ((period_value // 256) | 0x80).to_bytes(1, byteorder="little")

            match channel:
                case 0:
                    return (b"\x06\0" + duty_time_byte + envelope_byte + period_value_low_byte) + period_value_high_byte
                case 1:
                    return (b"\x07" + duty_time_byte + envelope_byte + period_value_low_byte) + period_value_high_byte

        if channel == 2:
            return b"" # TODO

        if channel == 3:
            # The "notes" specified in Trackerboy don't actually match the standard frequencies of musical notes.
            # This confused me (tecanec) to no end until I actually read the Trackerboy manual...
            freq_exponent = 14 - ((self.note + 3) // 4)
            freq_div = 7 - ((self.note + 3) % 4)
            
            envelope_byte = emit_state["effect_state"]["envelope"].to_bytes(1, byteorder="little")

            freq_state_val = ((freq_exponent << 4) + (emit_state["effect_state"]["duty"] << 3) + freq_div)
            freq_state_byte = freq_state_val.to_bytes(1, byteorder="little", signed=False)

            return b"\x09" + envelope_byte + freq_state_byte
    
    def get_size(self, channel):
        match channel:
            case 0:
                return 6
            case 1:
                return 5
            case 2:
                return 0
            case 3:
                return 3

class JumpEvent(Event):
    def __init__(self, time, section):
        super().__init__(time)

        self.section = section
    
    def emit(self, emit_state):
        song = emit_state["song"]

        offset = -emit_state["next_byte_index"] - 3
        # for section in song.sections[:self.section]:
        #     for channel_i in range(4):
        #         pattern = song.patterns[channel_i][section[channel_i]]
        #         if pattern == None:
        #             continue
        #         for pattern_event in pattern.events:
        #             offset -= pattern_event.get_size(channel_i)
        offset += emit_state["section_starts"][self.section]
        
        offset_bytes = offset.to_bytes(2, byteorder="little", signed=True)

        delay = 99999
        for channel_i in range(4):
            pattern = song.patterns[channel_i][song.sections[self.section][channel_i]]
            if pattern == None:
                continue
            pattern_start_time = pattern.events[0].time
            if pattern_start_time < delay:
                delay = pattern_start_time
        delay_byte = pattern_start_time.to_bytes(1, byteorder="little")

        return b"\x03" + offset_bytes + delay_byte

    def get_size(self, channel):
        return 4

class ParameterEvent(Event):
    def __init__(self, time, parameter, value):
        super().__init__(time)

        self.parameter = parameter
        self.value = value
    
    def emit(self, emit_state):
        if verbose:
            channel = emit_state["channel"]
            old_value = emit_state["effect_state"][self.parameter]
            print(f"{channel}.{self.parameter}: {old_value} → {self.value}")

        emit_state["effect_state"][self.parameter] = self.value

        return b""
    
    def get_size(self, channel):
        return 0

def read_int(in_stream, num_bytes):
    in_bytes = in_stream.read(num_bytes)
    return int.from_bytes(in_bytes, byteorder="little")

def load_module(in_stream):
    module_signature = in_stream.read(12)
    if module_signature != b"\0TRACKERBOY\0":
        print(module_signature)
        return "INVALID"
    
    in_stream.read(16) # Unknown meaning

    module_title = in_stream.read(32).rstrip(b"\0")
    author = in_stream.read(32).rstrip(b"\0")
    copyright = in_stream.read(32).rstrip(b"\0")

    in_stream.read(36) # Unknown meaning

    out_module = Module(module_title, author, copyright)

    for _ in range(100):
        section_tag = in_stream.read(4)
        if section_tag == b"\0YOB":
            # This isn't section header. This is start of footer!
            footer = in_stream.read(8)
            if footer != b"REKCART\0":
                return "INVALID"
            break

        section_length = read_int(in_stream, 4)

        match section_tag:
            case b"COMM":
                # Comment section. Contents bear no meaning.
                in_stream.read(section_length)
            case b"SONG":
                # Song section
                song_title_length = read_int(in_stream, 2)
                song_title = in_stream.read(song_title_length)

                rows_per_beat = read_int(in_stream, 1)
                rows_per_measure = read_int(in_stream, 1)
                speed = read_int(in_stream, 1)
                num_segments = read_int(in_stream, 1) + 1
                rows_per_segment = read_int(in_stream, 1) + 1
                num_patterns = read_int(in_stream, 1)
                in_stream.read(2) # Unknown meaning

                song = Song(song_title, rows_per_beat, rows_per_measure, speed, rows_per_segment)

                for _ in range(num_segments):
                    sq1_pattern_index = read_int(in_stream, 1)
                    sq2_pattern_index = read_int(in_stream, 1)
                    wav_pattern_index = read_int(in_stream, 1)
                    noi_pattern_index = read_int(in_stream, 1)
                    song.add_section([sq1_pattern_index, sq2_pattern_index, wav_pattern_index, noi_pattern_index])
                
                for _ in range(num_patterns):
                    pattern_channel = read_int(in_stream, 1)
                    pattern_id = read_int(in_stream, 1)
                    
                    if verbose:
                        print(f"Loading pattern {pattern_id} of channel {pattern_channel}...")
                    
                    new_pattern = Pattern()

                    num_event_times = read_int(in_stream, 1) + 1
                    for _ in range(num_event_times):
                        event_time = read_int(in_stream, 1)

                        tone = read_int(in_stream, 1)
                        # Add note event later so effects can be applied first
                        
                        in_stream.read(1) # Unknown meaning

                        for _ in range(3):
                            effect_code = read_int(in_stream, 1)
                            effect_parameter = read_int(in_stream, 1)

                            match effect_code:
                                case 0:
                                    pass
                                case 1:
                                    new_pattern.add_event(JumpEvent(event_time + 1, effect_parameter))
                                case 6:
                                    new_pattern.add_event(ParameterEvent(event_time, "envelope", effect_parameter))
                                case 7:
                                    new_pattern.add_event(ParameterEvent(event_time, "duty", effect_parameter))
                                case _:
                                    assert(False)

                        if tone == 0x55:
                            # TODO: Implement note stop event and use that here
                            pass
                        elif tone != 0:
                            new_pattern.add_event(NoteEvent(event_time, tone))

                    song.add_pattern(pattern_channel, pattern_id, new_pattern)

                out_module.add_song(song)
            case b"WAVE":
                wave_id = read_int(in_stream, 1)

                wave_name_length = read_int(in_stream, 2)
                wave_name = in_stream.read(wave_name_length)

                wave_shape = in_stream.read(16)

            case _:
                section_tag_byte_formatted = " ".join(f"{c:02x}" for c in section_tag)
                print(f"Unexpected section tag: {section_tag} ({section_tag_byte_formatted})")
                assert(False)
    
    return out_module

def compile_file(infile, outfile):
    instream = open(infile, "rb")
    module = load_module(instream)
    compiled = module.songs[0].emit_yeller_code()
    os.makedirs(os.path.dirname(outfile), exist_ok=True)
    outstream = open(outfile, 'w+b')
    outstream.write(compiled)