from py_huff.compile import compile
from py_huff.utils import keccak256
from typing import Callable
from typing import Generator, NamedTuple, Sequence
import re

METH_PATH = 'src/meth-huff/METH.huff'

Immutable = NamedTuple(
    'Immutable', [('src', str), ('length', int), ('var_name', str)])
Push = NamedTuple('Push', [('offset', int), ('data', bytes)])


IMMUTABLES: Sequence[Immutable] = [
    Immutable('old-weth', 20, 'oldWeth'),
    Immutable('cached-domain-separator', 32, 'domainSeparator')
]


WORD = 32
PUSH_OFFSET = 0x60 - 1
OP_RETURN = 0xf3
PUSH_OPS = [*range(0x60, 0x80)]

DOMAIN = 'meth'


class OneOffRepl:
    total: int
    value: str

    def __init__(self, value: str) -> None:
        self.value = value
        self.total = 0

    def __call__(self, m: re.Match) -> str:
        self.total += 1
        assert len(m.groups()) == 2, f'More than 2 groups in match group'
        return f'{m.group(1)}{self.value}{m.group(2)}'


def transform_file(path: str, pattern: str, value: str):
    with open(path, 'r') as f:
        contents = f.read()
    with open(path, 'w') as f:
        repl = OneOffRepl(value)
        out = re.sub(pattern, repl, contents, flags=re.S)
        assert repl.total > 0, f'Found no matches for {pattern!r} in {path}'
        assert repl.total == 1, f'Found more than 1 match for {pattern!r} in {path}'
        f.write(out)


def find_opcodes(bytecode, op):
    i = 0
    while (byte := bytecode[i]) != op:
        if byte in PUSH_OPS:
            i += (byte & 0x1f) + 1
        i += 1
    return i


def get_pushes(bytecode: bytes) -> Generator[Push, None, None]:
    i = 0
    while i < len(bytecode):
        b = bytecode[i]
        i += 1
        if b in PUSH_OPS:
            length = b - PUSH_OFFSET
            data = bytecode[i: i + length]
            yield Push(i, data + b'\0' * (length - len(data)))
            i += length


def immutable_insertions(pushes: list[Push]) -> str:

    code: list[str] = []

    for im in IMMUTABLES:
        assert im.length in range(1, WORD + 1)
        preimage = f'meth.immutable.{im.src}'
        hash = keccak256(preimage.encode())[WORD-im.length:]
        found = 0
        code.append('')
        code.append(f'// Insert \'{preimage}\' into final code.')
        for push in pushes:
            if push.data != hash:
                continue
            size = '' if im.length == 32 else str(im.length * 8)
            code.append(f'mstore{size}(0x{push.offset:04x}, {im.var_name})')
            found += 1

        assert found > 0, f'No constants for {im.src} found ("{preimage}" -> 0x{hash.hex()})'

    return ''.join(
        (' ' * 12 + row).rstrip() + '\n'
        for row in code
    )


def main():
    out = compile(METH_PATH, {})
    runtime = out.runtime

    transform_file(
        'src/METHConstants.sol',
        r'(bytes constant METH_RUNTIME =\n    hex")(?:[A-Fa-f0-9]+)(";)',
        runtime.hex()
    )

    pushes = list(get_pushes(runtime))

    transform_file(
        'src/deployment/METHLab.sol',
        r'(\n +// build:meth-immutable-start\n)(?:.*)(\n +// build:meth-immutable-end\n)',
        immutable_insertions(pushes),
    )


if __name__ == '__main__':
    main()
