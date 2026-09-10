"""Offline protocol oracle + ST source contracts, NOT execution of PLC code.

Fixtures come from BA_2316_EN 7.3/8.10/8.12. No socket, PLC or device access.
The oracle exercises fragmented wire examples; source assertions tie its key
framing/ordering assumptions to the candidate. PLE Build and field tests remain
separate gates; this does not prove firmware EOC or socket lifecycle behavior.
"""
import math
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "src/plc/project/Station010/FB_Wp100BursterSingleOwner.st").read_text(encoding="utf-8")
PARTS = dict(re.findall(r"\(\* ===== OBJECT ([\w/]+) ===== \*\)(.*?)(?=\(\* ===== OBJECT |\Z)", SOURCE, re.S))


def st_bytes(literal):
    return re.sub(r"\$([0-9A-Fa-f]{2})", lambda m: chr(int(m[1], 16)), literal).encode("ascii")


def response(payload, extra_cr=False):
    return b"\x02" + payload + b"\r\n\x03" + (b"\r" if extra_cr else b"") + b"\x04\r"


class EthernetResponse:
    """Strict reference decoder, intentionally not a replacement PLC driver."""
    def __init__(self):
        self.buffer = bytearray()

    def feed(self, chunk):
        self.buffer.extend(chunk)
        data = bytes(self.buffer)
        if not data.startswith(b"\x02"):
            raise ValueError("missing STX")
        if b"\x03" not in data:
            if len(data) > 128:
                raise ValueError("oversize")
            return None
        body, tail = data[1:].split(b"\x03", 1)
        if len(body) > 127 or not body.endswith(b"\r\n"):
            raise ValueError("invalid payload terminator/length")
        payload = body[:-2]
        if not all(32 <= byte <= 126 for byte in payload):
            raise ValueError("control byte in payload")
        endings = (b"\x04\r", b"\r\x04\r")
        if tail in endings:
            return payload.decode("ascii")
        if any(end.startswith(tail) for end in endings):
            return None
        raise ValueError("invalid trailer or coalesced next frame")


def number_oracle(text, kind):
    """Specification oracle: returns Ohm, Celsius, or a register value."""
    text = text.strip(" ")
    if kind == 0:
        if not re.fullmatch(r"[0-9]{1,5}", text) or int(text) > 32767:
            raise ValueError("invalid register")
        return int(text)
    pattern = r"([+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[Ee][+-]?[0-9]{1,2})?) *(.*)"
    match = re.fullmatch(pattern, text)
    if match is None or len(match[1]) > 63 or len(match[2]) > 63:
        raise ValueError("invalid numeric grammar")
    suffix = match[2]
    if kind == 1:
        unit = re.fullmatch(r"(OHM|MOHM|KOHM)(?: *, *[<=>])?", suffix)
        if unit is None:
            raise ValueError("invalid resistance units")
        scale = {"OHM": 1.0, "MOHM": 0.001, "KOHM": 1000.0}[unit[1]]
    elif kind == 2 and suffix == "CEL":
        scale = 1.0
    else:
        raise ValueError("invalid temperature units")
    value = float(match[1]) * scale
    if not math.isfinite(value) or abs(value) > 1_000_000:
        raise ValueError("overflow")
    if kind == 1 and value < 0 or kind == 2 and not -273.15 <= value <= 2000:
        raise ValueError("out of range")
    return value


class WireExamples(unittest.TestCase):
    def test_actual_st_command_frames_all_programs(self):
        exchange = PARTS["Exchange"]
        prefix = re.search(r"_tx := CONCAT\('([^']+)', CommandText\)", exchange)[1]
        suffix = re.search(r"_tx := CONCAT\(_tx, '([^']+)'\)", exchange)[1]
        for program in range(16):
            actual = st_bytes(prefix) + f"*RCL {program}".encode() + st_bytes(suffix)
            self.assertEqual(actual, b"\x040000sr\x02" + f"*RCL {program}".encode() + b"\n\x03\r")
        self.assertIn("CONCAT('*RCL ', INT_TO_STRING(_program))", PARTS["SelectProgram"])

    def test_actual_st_poll_frame_and_ethernet_no_bcc(self):
        literal = re.search(r"_tx := '([^']+)'", PARTS["Exchange"])[1]
        self.assertEqual(st_bytes(literal), b"\x040000po\x05\r")
        self.assertNotIn("BCC", PARTS["Exchange"])
        self.assertNotIn("_tx := '$06'", PARTS["Exchange"])

    def test_every_fragment_boundary_with_both_ethernet_trailers(self):
        for payload in (b"0", b"256", b'0,"NO ERROR"', b"2.0000E+00 MOHM, =", b"RESISTOMAT2316, V1, 123, V2"):
            for extra in (False, True):
                frame = response(payload, extra)
                for split in range(1, len(frame)):
                    with self.subTest(payload=payload, split=split, extra=extra):
                        decoder = EthernetResponse()
                        self.assertIsNone(decoder.feed(frame[:split]))
                        self.assertEqual(decoder.feed(frame[split:]), payload.decode())

    def test_one_byte_at_a_time_never_completes_before_eot_cr(self):
        frame = response(b"2.000 MOHM")
        decoder = EthernetResponse()
        for byte in frame[:-1]:
            self.assertIsNone(decoder.feed(bytes([byte])))
        self.assertEqual(decoder.feed(frame[-1:]), "2.000 MOHM")

    def test_rejects_bad_framing_overflow_and_next_response(self):
        bad = (b"\x150\r", b"x" + response(b"0"), b"\x020\x03\x04\r",
               response(b"\x060"), response(b"A" * 126),
               response(b"0") + response(b"1"), b"\x020\r\n\x03\x06\r")
        for frame in bad:
            with self.subTest(frame=frame):
                with self.assertRaises(ValueError):
                    EthernetResponse().feed(frame)

    def test_truncated_response_is_not_a_result(self):
        frame = response(b"2.000 MOHM")
        for end in range(1, len(frame)):
            self.assertIsNone(EthernetResponse().feed(frame[:end]))


class ValueExamples(unittest.TestCase):
    def test_resistance_units_and_comparator(self):
        for text, value in (("0 OHM", 0), ("2MOHM", .002), ("2.0 MOHM, =", .002),
                            ("+2E-3 OHM, <", .002), (" .25 KOHM,> ", 250)):
            self.assertAlmostEqual(number_oracle(text, 1), value)

    def test_register_and_temperature(self):
        for value in (0, 15, 16, 256, 272, 32767):
            self.assertEqual(number_oracle(str(value), 0), value)
        self.assertEqual(number_oracle("-10.5 CEL", 2), -10.5)
        self.assertEqual(number_oracle("25 CEL", 2), 25)

    def test_invalid_is_not_zero_or_good(self):
        for text in ("", "NaN OHM", "INF OHM", "OVERLOAD", "-1 MOHM", "2 OHM/m", "2 V",
                     "2 OHM,x", "2 OHM, = =", "2E OHM", "1E99 OHM", "2", "2,5 MOHM"):
            with self.subTest(text=text):
                with self.assertRaises(ValueError):
                    number_oracle(text, 1)
        for text in ("-1", "+0", "65535", "1.0", "0,NO ERROR", "NaN"):
            with self.assertRaises(ValueError):
                number_oracle(text, 0)
        for text in ("-274 CEL", "2001 CEL", "25 C", "25 K"):
            with self.assertRaises(ValueError):
                number_oracle(text, 2)


class SourceContracts(unittest.TestCase):
    def test_one_owner_no_standard_driver_calls_or_runtime_access(self):
        self.assertEqual(len(re.findall(r"\w+\s*:\s*OpconTcpClientIpV4\s*;", SOURCE)), 1)
        self.assertNotIn("IpBurster2316", SOURCE)
        self.assertNotIn("iStandardDriver", SOURCE)
        self.assertIn("IMPLEMENTS IBursterResis2316", PARTS["FB_Wp100BursterSingleOwner"])
        body = PARTS["FB_Wp100BursterSingleOwner"].split("(* ===== IMPLEMENTATION ===== *)")[1]
        self.assertNotIn("_socket.", body)
        for method in ("Open", "Close", "Write", "Read", "ClearError"):
            self.assertEqual(len(re.findall(r"_socket\." + method + r"\(", SOURCE)), 1)

    def test_selection_readback_and_errors_before_verification(self):
        code = PARTS["SelectProgram"]
        self.assertLess(code.index("'*RCL '"), code.index("'*RCL?'"))
        self.assertLess(code.index("'SYST:ERR?'"), code.index("SelectionVerified := TRUE"))
        self.assertIn("_reg <> INT_TO_UINT(_program)", code)
        self.assertIn("ProgramNo <> _program", code)
        self.assertIn("ProgramNo < 0", code)
        self.assertIn("ProgramNo > 15", code)
        self.assertNotIn("_socket.Close", code)

    def test_actual_error_status_guard_accepts_quoted_zero_only(self):
        # Extract the real ST equality guard, rather than testing a separate
        # parser that could silently disagree with the deployed implementation.
        code = PARTS["SelectProgram"]
        guard = re.search(
            r"IF \( LastResponse <>.*?THEN SelectProgram := Fail\(Code := 1106\); RETURN; END_IF",
            code, re.S,
        )[0]
        accepted = set(re.findall(r"LastResponse <> '([^']*)'", guard))
        self.assertEqual(accepted, {'0,NO ERROR', '0, NO ERROR', '0,"NO ERROR"', '0, "NO ERROR"'})
        self.assertEqual(guard.count(' AND'), len(accepted) - 1)
        self.assertNotIn(' OR', guard)
        self.assertLess(code.index(guard), code.index('SelectionVerified := TRUE'))
        for reply in accepted:
            self.assertFalse(all(reply != literal for literal in accepted))
        for reply in ('', '0', '0,', '0,""', '0,"NO ERROR', '0,NO ERROR"',
                      '10,"NO ERROR"', '-100,"COMMAND ERROR"', '-200,"EXECUTION ERROR"',
                      '-100,"NO ERROR"', '0,"EXECUTION ERROR"', '0,"NO ERROR"junk',
                      '0,"NO ERROR",-100', 'garbage0,"NO ERROR"', 'NaN,"NO ERROR"',
                      '0.0,"NO ERROR"', '0,"NO ERROR"\r\n'):
            with self.subTest(reply=reply):
                self.assertTrue(all(reply != literal for literal in accepted))

    def test_measurement_is_once_per_invocation_and_old_eoc_not_result(self):
        code = PARTS["MeasCmd"]
        self.assertEqual(code.count("CommandText := 'INIT',"), 1)
        self.assertLess(code.index("_measureMayRun := TRUE"), code.index("CommandText := 'INIT',"))
        self.assertLess(code.index("Phase := 6"), code.index("'INIT:CONT 0'"))
        self.assertIn("( _reg AND 272 ) <> 0", code)
        self.assertIn("( _reg AND 256 ) <> 0 ) AND ( ( _reg AND 16 ) = 0", code)
        self.assertIn("( _reg AND 512 ) <> 0", code)
        self.assertEqual(code.count("ResultValid := TRUE"), 1)
        self.assertLess(code.index("Kind := 1"), code.index("ResultValid := TRUE"))
        self.assertIn("_measureTimer.Q", code)
        self.assertNotIn("_socket.Open(", code)

    def test_manual_and_automatic_share_serialized_preparation(self):
        code = PARTS["MeasCmd"]
        self.assertIn("_measProgram := RequestedProgramNo", code)
        self.assertIn("RequestedProgramNo <> _measProgram", code)
        self.assertIn("( _measPrep = 1 ) AND ( Operation <> 0 ) AND ( Operation <> 1 )", code)
        self.assertIn("( _measPrep = 2 ) AND ( Operation <> 0 ) AND ( Operation <> 2 )", code)
        self.assertLess(code.index("_ret := Open()"), code.index("SelectProgram(ProgramNo := _measProgram)"))
        self.assertIn("IF ( NOT SelectionVerified ) OR ( SelectedProgram <> _measProgram )", code)
        self.assertLess(code.index("'*RCL?'"), code.index("CommandText := 'INIT',"))
        self.assertIn("_reg <> INT_TO_UINT(_measProgram)", code)
        self.assertIn("_measPrep := 0", PARTS["Cleanup"])

    def test_only_one_instance_and_no_second_socket_in_selector(self):
        root = ROOT / "src/plc/project/Station010"
        selector = (root / "FB_Wp100BursterProgramSelect.st").read_text()
        gvl = (root / "AiWp100.gvl.st").read_text()
        self.assertNotIn("OpconTcpClientIpV4", selector)
        self.assertNotIn("Peripherals.", selector)
        self.assertEqual(gvl.count("Burster : FB_Wp100BursterSingleOwner;"), 1)
        self.assertIn("AiWp100.Burster.Open()", selector)
        self.assertIn("AiWp100.Burster.SelectProgram(ProgramNo := _requestedProgramNo)", selector)
        reset_prefix = selector[selector.index("IF ( NOT Execute )"):selector.index("CASE _state OF")]
        self.assertIn("( _state = 100 )", reset_prefix)
        self.assertIn("RETURN;", reset_prefix)
        self.assertNotIn(".Reset(", reset_prefix)
        self.assertIn("_state := 90; // Continue the pending owner's cleanup", selector)
        self.assertIn("_ret := RUNNING;", selector)  # no previous error reused on a new request

    def test_cleanup_finishes_pending_call_eot_before_close_and_blocks(self):
        code = PARTS["Cleanup"]
        self.assertLess(code.index("IF ( _cleanupTimer.Q )"), code.index("CASE _cleanupPhase"))
        self.assertLess(code.index("CommandText := LastCommand"), code.index("_ret := PollIo()"))
        self.assertLess(code.index("_ioPointer := ADR(_eot)"), code.index("_ioKind := 4"))
        self.assertEqual(code.count("_ioKind := 4"), 1)
        self.assertIn("CleanupBlocked := TRUE", code)
        self.assertIn("IF ( NOT _socket.IsOpen ) THEN _cleanupPhase := 50", code)
        self.assertIn("IF ( _ret <> RUNNING )", code)
        self.assertIn("CleanupBlocked", PARTS["Open"])

    def test_first_error_validity_and_no_range_side_effect(self):
        code = PARTS["Fail"]
        self.assertIn("IF ( ErrorCode = 0 )", code)
        self.assertIn("LastSocketError := _socket.LastError", code)
        self.assertIn("SelectionVerified := FALSE", code)
        self.assertIn("ResultValid := FALSE", code)
        self.assertIn("SetRangeCmd := Fail(Code := 1301)", PARTS["SetRangeCmd"])
        self.assertNotIn("Exchange(", PARTS["SetRangeCmd"])
        self.assertIn("LastError := LastSocketError", PARTS["LastError/Get"])

    def test_bounded_parser_receiver_and_explicit_offline_staging(self):
        self.assertIn("FOR n := 1 TO 16 DO", PARTS["Exchange"])
        self.assertIn("_ioLength := 1", PARTS["Exchange"])
        self.assertIn("_rxCount >= 127", PARTS["Exchange"])
        self.assertIn("_exchangeState := 199", PARTS["Exchange"])
        self.assertIn("STRING_TO_REAL(numeric)", PARTS["ParseNumber"])
        self.assertIn("suffix = 'MOHM'", PARTS["ParseNumber"])
        self.assertIn("status: integrated_offline_candidate", (ROOT / "specs/common/FB_Wp100BursterSingleOwner.yaml").read_text())


if __name__ == "__main__":
    unittest.main(verbosity=2)
