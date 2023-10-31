from common import *


def test_dispatcher_arrival_block_offset():
    print(f'FUNCS: {FUNCS}')
    blocks: list[Fn | str | None] = [None] * TOTAL_BLOCKS

    # Check that functions don't intersect
    for i, f in enumerate(FUNCS):
        b = f.selector[0]
        maybe_f = blocks[b]
        if isinstance(maybe_f, Fn):
            assert 0, f'Functions {maybe_f.sig} and {f.sig} have the same start byte (0x{maybe_f.num:08x} vs. 0x{f.num:08x})'
        elif isinstance(maybe_f, str):
            assert 0, f'Start of {f.sig} intersects with "{maybe_f}" at block 0x{i:02x}'
        blocks[b] = f

        for d in range(1, f.size):
            existing_val = blocks[b + d]
            if isinstance(existing_val, Fn):
                assert 0, f'Continuation of {f.sig} intersects with start of {existing_val.sig} at block {i:02x}'
            elif isinstance(existing_val, str):
                assert 0, f'Continuation of {f.sig} intersects with continuation of "{existing_val}" at block {i:02x}'
            blocks[b + d] = f.name

    code = compile_meth(True)

    last: None | Fn = None
    for i, val in enumerate(blocks):
        offset = block_offset(i)
        if isinstance(val, str):
            assert code[offset] != JUMPDEST, f'Continuation of {val} at {offset} is a JUMPDEST'
        else:
            last_fn_repr = ', start' if last is None else f', last fn: {last.name} @ 0x{last.selector[0]:02x}'
            desc = 'no_match' if val is None else 'function'
            assert code[offset] == JUMPDEST,\
                f'Missing JUMPDEST at {desc} block 0x{i:02x}; add {find_nearest_jumpdests(code, offset)} padding to 0x{i-1:02x} ({offset}{last_fn_repr})'
            if isinstance(val, Fn):
                last = val

    # Check for the __NO_MATCH() reverting block sequences
    assert blocks[TOTAL_BLOCKS - 1] is None,\
        f'Last block 0x{TOTAL_BLOCKS - 1:02x} expected to be empty no match'
    for i, val in enumerate(blocks[:TOTAL_BLOCKS - 1]):
        offset = block_offset(i)
        if val is None:
            assert code[offset:offset+BLOCK_SIZE] == NO_MATCH,\
                f'Invalid function arrival 0x{i:02x} missing NO_MATCH ({bytes(NO_MATCH[:10]).hex()}...), found {code[offset:offset+len(NO_MATCH)].hex()} instead'
        elif isinstance(val, Fn):
            assert code[offset:offset+NO_MATCH_CORE_LEN] != NO_MATCH[: NO_MATCH_CORE_LEN],\
                f'Found core of no match sequence while expecting function for [0x{val.num:08x}] {val.sig} @ 0x{i:02x}'


def test_no_duplicate_names():
    names = set()
    for f in FUNCS:
        assert f.name not in names, f'Duplicate name "{f.name}"'
        names.add(f.name)
