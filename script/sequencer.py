from eth_utils import function_signature_to_4byte_selector
from collections import namedtuple

BitSeq = namedtuple('BitSeq', ['bits', 'size'])
SeqChange = namedtuple('SeqChange', ['bit', 'seq'])


def empty():
    return BitSeq(0, 0)


def add_bit(seq, bit):
    bits, size = seq
    return BitSeq(bits | (bit << size), size + 1)


SIGS = [
    # metadata
    'name()',
    'symbol()',
    'decimals()',
    # global
    'totalSupply()',
    # transfer related
    'transferFrom(address,address,uint256)',
    'transfer(address, uint256)',
    'balanceOf(address)',
    # approval
    'approve(address,uint256)',
    'allowance(address, address)',
    # deposit
    'deposit()',
    'depositTo(address)',
    'depositAmountTo(address, uint256)',
    'depositAmount(uint256)',
    # withdraw
    'withdraw(uint256)',
    'withdrawTo(address, uint256)',
    'withdrawFrom(address, uint256)',
    'withdrawFromTo(address, address, uint256)',
    # permit
    'DOMAIN_SEPARATOR()',
    'nonces(address)',
    'permit(address, address, uint256, uint256, uint8, bytes32, bytes32)',
    # utility
    'multicall(bytes[])',
]
SELECTORS = [
    int.from_bytes(function_signature_to_4byte_selector(sig), 'big')
    for sig in SIGS
]
SIGS.append('receive()')
SELECTORS.append(0)


S_MASK = 0x31c00000
S_SHIFT = 22
MASK = S_MASK >> S_SHIFT

BITS = 5


def get_total_nums(seq_size):
    return seq_size // 12 * 8 + max(0, seq_size % 12 - 4)


def get_seq_nums(seq):
    total_groups = (seq.size + 7) // 12
    for group_shift in range((total_groups - 1) * 12, -1, -12):
        gb = (seq.bits >> group_shift) & 0xfff
        for ni in range(min(seq.size - group_shift, 12) - 5, -1, -1):
            yield (gb >> ni) & 0x1f


def get_indexed_nums(seq):
    total_nums = get_total_nums(seq.size)
    yield from zip(range(total_nums - 1, -1, -1), get_seq_nums(seq))


def create_get_seq_state(no_match_indices):
    def get_seq_state(seq):
        if seq.size > 48:
            return False

        valid_nums = set()
        no_match_nums = set()

        print(f'  seq: {show_seq(seq)}')
        for i, num in get_indexed_nums(seq):
            if num in valid_nums or num < 3:
                print(f'  {num:02} ({i}) <INV>')
                return False
            else:
                print(f'  {num:02} ({i})')
                pass

            if i in no_match_indices:
                no_match_nums.add(num)
            else:
                if num in no_match_nums:
                    print(f'  {num:02} ({i}) <INV>')
                    return False
                valid_nums.add(num)
        return True

    return get_seq_state


def show_seq(seq):
    bits = f'{seq.bits:b}'.zfill(seq.size)
    return f'{bits} ({seq.size})'


def show_tree(tree):
    print(f'tree ({len(tree)}):')
    for bit, seq in tree:
        print(f'(+{bit}) {show_seq(seq)}')
    print()
    pass


def main_prep_seq():
    final_seq = BitSeq(
        int('001011111011010110011100011010100011100100110000', 2),
        48
    )
    indices = set()
    ind_to_v = dict()
    x = 0
    for i in range(MASK + 1):
        ind = i & MASK
        if ind not in indices:
            indices.add(ind)
            ind_to_v[x] = ind
            x += 1
    v_to_rel_dest = dict()
    for i, num in get_indexed_nums(final_seq):
        v = ind_to_v[i]
        print(f'hex(v): {hex(v)}')
        v_to_rel_dest[v] = num

    v_to_fn = dict()
    for sel, fn in zip(SELECTORS, SIGS):
        v = (sel & S_MASK) >> S_SHIFT
        v_to_fn[v] = (sel, fn)

    existing_dests = set()
    for v, rel_dest in sorted(v_to_rel_dest.items(), key=lambda p: p[1]):
        if rel_dest in existing_dests:
            continue
        existing_dests.add(rel_dest)
        dest = f'dest_0x{rel_dest << 4:03x}'
        sel, fn = v_to_fn.get(v, (None, None))
        if fn is None:
            print(f'    {dest}: NO_MATCH()')
        elif fn == 'receive()':
            print(f'    {dest}: RECEIVE_CHECK(deposit_final_dest)')
        else:
            final_dest_label = fn.split('(', 1)[0] + '_final_dest'
            print(f'    {dest}: FUNC_CHECK(0x{sel:08x}, {final_dest_label})')


def main_prep_code_61():
    indices = {
        x & MASK
        for x in range(MASK + 1)
    }
    ind_to_fn = dict()
    for sel, fn in zip(SELECTORS, SIGS):
        ind = (sel >> S_SHIFT) & MASK
        ind_to_fn[ind] = (sel, fn)

    for ind in sorted(indices):
        sel, fn = ind_to_fn.get(ind, (None, None))

        if sel is not None:
            print(f'0x{sel:08x} (0x{(sel >> S_SHIFT) & MASK:03x}): {fn}')

    for ind in sorted(indices):
        dest = f'dest_0x{(ind << 4) + 0x13:03x}'
        sel, fn = ind_to_fn.get(ind, (None, None))
        if fn is None:
            print(f'    {dest}: NO_MATCH()')
        elif fn == 'receive()':
            print(f'    {dest}: RECEIVE_CHECK(deposit_final_dest)')
        else:
            final_dest_label = fn.split('(', 1)[0] + '_final_dest'
            print(f'    {dest}: FUNC_CHECK(0x{sel:08x}, {final_dest_label})')


def main_prep_code_55():
    ind_to_fn = dict()
    for sel, fn in zip(SELECTORS, SIGS):
        ind = (sel >> 20) | 15
        ind_to_fn[ind] = (sel, fn)

    for ind in sorted({x | 15 for x in range(4096)}):
        dest = f'dest_0x{ind:03x}'
        sel, fn = ind_to_fn.get(ind, (None, None))
        if fn is None:
            print(f'    {dest}: NO_MATCH()')
        elif fn == 'receive()':
            print(f'    {dest}: RECEIVE_CHECK(deposit_final_dest)')
        else:
            final_dest_label = fn.split('(', 1)[0] + '_final_dest'
            print(f'    {dest}: FUNC_CHECK(0x{sel:08x}, {final_dest_label})')


def main_find_seq():
    indices = set()
    vmap = dict()
    vmap_rev = dict()
    x = 0
    for i in range(MASK + 1):
        ind = i & MASK
        if ind not in indices:
            indices.add(ind)
            vmap[x] = ind
            vmap_rev[ind] = x
            x += 1

    print(f'vmap: {vmap}')

    ind_fn_map = dict()
    for sel, fn in zip(SELECTORS, SIGS):
        ind = (sel & S_MASK) >> S_SHIFT
        ind_fn_map[ind] = fn
        print(f'0x{sel:08x} {fn}')

    no_match_indices = {
        vmap_rev[ind]
        for ind in indices if ind not in ind_fn_map
    }

    for ind in sorted(no_match_indices):
        print(f'no match: 0x{vmap[ind]:02x}')

    history_tree = [
        SeqChange('N', empty())
    ]
    is_valid = create_get_seq_state(no_match_indices)
    iterc = 0
    print()
    while True:
        iterc += 1
        if iterc % 100_000 == 0:
            print(f'iterc: {iterc:,} ({history_tree[-1].seq.size})')
        # print('\n' + '-'*50)
        # show_tree(history_tree)
        # if input('>> ') == 'QUIT':
        #     break

        last_seq = history_tree[-1].seq
        new_seq = add_bit(last_seq, 0)
        # print('checking 0:')
        if is_valid(new_seq):
            if new_seq.size == 48:
                msg = f'found: {new_seq.bits:048b}'
                with open('good-seq.txt', 'w') as f:
                    f.write(msg)
                print(msg)
                break
            history_tree.append(SeqChange(0, new_seq))
            continue
        new_seq = add_bit(last_seq, 1)
        # print('checking 1:')
        if is_valid(new_seq):
            if new_seq.size == 48:
                msg = f'found: {new_seq.bits:048b}'
                with open('good-seq.txt', 'w') as f:
                    f.write(msg)
                print(msg)
                break
            history_tree.append(SeqChange(1, new_seq))
            continue

        # prev_seq = history_tree[-1].seq
        while history_tree[-1].bit == 1:
            history_tree.pop()
            # popped_bit, _ = history_tree.pop()
            # print(f'popped {popped_bit}')

        history_tree[-1] = SeqChange(1, add_bit(history_tree[-2].seq, 1))
        # print(f'{show_seq(prev_seq)} -> {show_seq(history_tree[-1].seq)}')


if __name__ == '__main__':
    # main_prep_seq()
    main_prep_code_55()
