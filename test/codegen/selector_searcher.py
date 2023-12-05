from typing import Callable, Generator, Iterable
from common import *

BITS = 7
SELECTOR_BITS = 32


def mask(size: int) -> int:
    return (1 << size) - 1


def valid(table: Callable[[int], int]) -> bool:
    space: list[None | str] = [None] * 128
    space[0] = 'dispatcher'

    for f in FUNCS:
        assert f.size >= 1
        i = table(f.num)
        chunks = f.size * 64 // 31
        if i + chunks >= 128:
            return False
        for c in range(chunks):
            if space[i + c] is not None:
                return False
            space[i + c] = f.name
    return True


def cycler(*combo: Iterable[int]) -> Generator[tuple[int, ...], None, None]:
    if not combo:
        yield tuple()
        return
    for el in combo[0]:
        for sub_combo in cycler(*combo[1:]):
            yield (el,) + sub_combo


def cycle_offsets(offset: int, *sizes: int) -> Generator[tuple[int, ...], None, None]:
    if not sizes:
        yield tuple()
        return
    for sub_offset in range(offset, SELECTOR_BITS - sum(sizes) + 1):
        for offsets in cycle_offsets(sub_offset + sizes[0], *sizes[1:]):
            yield (sub_offset, ) + offsets


def main():
    for f in FUNCS:
        print(f'- {f.name}')
    print('\n\n')

    # for mask1, mask2, mask3 in cycler(
    #     range(1, 1 << BITS),
    #     range(1, 1 << BITS),
    #     range(1, 1 << SELECTOR_BITS),
    # ):
    #     # print(mask1, mask2, shift)
    #     if valid(lambda sel: ((sel ^ mask3) % mask1) ^ (sel % mask2)):
    #         print()
    #         print(f'low_mask : 0x{mask1:02x}')
    #         print(f'high_mask: 0x{mask1:02x}')
    size_a = 1
    size_b = 1
    size_c = 2
    size_d = 2
    size_e = 1
    for a, b, c, d, e in cycle_offsets(0, size_a, size_b, size_c, size_d, size_e):
        mask_a = mask(size_a) << a
        mask_b = mask(size_b) << b
        mask_c = mask(size_c) << c
        mask_d = mask(size_d) << d
        mask_e = mask(size_e) << e
        final_mask = (mask_a >> a)\
            | (mask_b >> (b - size_a))\
            | (mask_c >> (c - size_a - size_b))\
            | (mask_d >> (d - size_a - size_b - size_c))\
            | (mask_e >> (e - size_a - size_b - size_c - size_d))
        assert final_mask == mask(BITS)
        if valid(
            lambda s: (
                ((s & mask_a) >> a)
                | ((s & mask_b) >> (b - size_a))
                | ((s & mask_c) >> (c - size_a - size_b))
                | (mask_d >> (d - size_a - size_b - size_c))
                | (mask_e >> (e - size_a - size_b - size_c - size_d))
            ) + 1
        ):
            print(f'mask_a: {mask_a:032b}')
            print(f'mask_b: {mask_b:032b}')

    # for salt in range(1 << BITS):
    #     for m in range(1, 1 << BITS):
    #         if valid(lambda s: (s ^ salt) % m + 1):
    #             print()
    #             print(f'salt: 0x{salt:02x} ({salt:07b})')
    #             print(f'mask: 0x{m:02x} ({m:07b})')


if __name__ == '__main__':
    main()
