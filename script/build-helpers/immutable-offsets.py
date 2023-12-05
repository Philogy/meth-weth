import argparse
from py_huff.compile import compile
from py_huff.utils import keccak256
import json
from typing import Generator, NamedTuple, Sequence

Immutable = NamedTuple('Immutable', [('src', str), ('length', int)])
Push = NamedTuple('Push', [('offset', int), ('data', bytes)])


IMMUTABLES: Sequence[Immutable] = [
    Immutable('meth-weth.old-weth.address', 20)
]


WORD = 32
PUSH_OFFSET = 0x60 - 1
OP_RETURN = 0xf3
PUSH_OPS = [*range(0x60, 0x80)]


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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('file')
    parser.add_argument('--json', '-j', action='store_true')

    args = parser.parse_args()

    out = compile(args.file, {})

    pushes = list(get_pushes(out.runtime))

    constants: dict[str, list[int]] = {}

    for im in IMMUTABLES:
        assert im.length in range(1, WORD + 1)
        hash = keccak256(im.src.encode())[WORD-im.length:]
        constants[im.src] = [
            push.offset
            for push in pushes
            if push.data == hash
        ]
        assert constants[im.src], \
            f'No constants for {im.src} found (0x{hash.hex()})'

    if args.json:
        print(json.dumps(constants, indent=2))
    else:
        for name, offsets in constants.items():
            print(f'{name}: {", ".join(map(hex, offsets))}')


if __name__ == '__main__':
    main()
