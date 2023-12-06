import subprocess
from Crypto.Hash import keccak
from typing import NamedTuple

Fn = NamedTuple(
    'Fn',
    [
        ('name', str),
        ('sig', str),
        ('selector', bytes),
        ('num', int),
        ('size', int)
    ]
)

JUMPDEST = 0x5b
RETURNDATASIZE = 0x3d
REVERT = 0xfd

NO_MATCH_CORE_LEN = 3
NO_MATCH = bytes([JUMPDEST, RETURNDATASIZE, RETURNDATASIZE, REVERT] + [0] * 60)


def _get_sigs() -> list[str]:
    def clean_type(t: str) -> str:
        if t == 'int':
            return 'int256'
        if t == 'uint':
            return 'uint256'
        return t

    def sig_from_func(s: str) -> str:
        # Skip '#define function'
        r = s.split(' ', 2)[-1]
        assert r.count(')') == 2
        core_sig = r[:r.index(')') + 1]
        name = core_sig[:r.index('(')]  # )
        params = core_sig[r.index('(') + 1:r.index(')')]
        unnamed_types = [
            clean_type(p.strip().split(' ')[0])
            for p in params.split(',')
        ]
        return f'{name}({",".join(unnamed_types)})'

    with open('src/interfaces/IMETH.huff', 'r') as f:
        funcs = [
            line
            for line in f.read().strip().splitlines()
            if line.startswith('#define function')
        ]
        return list(map(sig_from_func, funcs))


BLOCK_SIZE = 64
TOTAL_BLOCKS = 256


def block_offset(index: int) -> int:
    return (BLOCK_SIZE - 1) + index * BLOCK_SIZE


def compile_meth(runtime: bool) -> bytes:
    flag = '-r' if runtime else '-b'
    direct_out = subprocess.getoutput(f'huffy {flag} src/meth-huff/METH.huff')
    out = direct_out.splitlines()[-1]
    return bytes.fromhex(out)


SIGS = _get_sigs()


def keccak256(b: bytes) -> bytes:
    return keccak.new(data=b, digest_bits=256).digest()


def _deltas(x: int):
    for i in range(1, x + 1):
        yield i
        yield -i


def find_nearest_jumpdests(code: bytes, offset: int) -> str:
    deltas = [
        -d
        for d in _deltas(100)
        if d + offset in range(len(code)) and code[d + offset] == JUMPDEST
    ][:3]  # Cap at 3 deltas

    return '/'.join(map(str, deltas))


def _get_func_size(name):
    return {
        'approve': 2,
        'withdrawTo': 2,
        'transferFrom': 2,
        'depositAndApprove': 2,
        'withdraw': 2,
        'withdrawFromTo': 2,
        'withdrawAll': 2,
        'transfer': 2,
        'sweepLost': 2,
        'withdrawAllTo': 2,
        'depositWithOldTo': 3,
        'permit': 4
    }.get(name, 1)


FUNCS = [
    Fn(
        name := sig.split('(', 1)[0],  # )
        sig,
        sel,
        int.from_bytes(sel, 'big'),
        _get_func_size(name)
    )
    for sig, sel in [
        ('fallback()', (0).to_bytes(4, 'big')),
        *(
            (sig, keccak256(sig.encode())[:4])
            for sig in SIGS
        )
    ]
]

FUNCS.sort(key=lambda f: f.num)
