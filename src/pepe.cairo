use starknet::ContractAddress;

#[abi]
trait IERC20 {
    fn name() -> felt252;
    fn symbol() -> felt252;
    fn decimals() -> u8;
    fn totalSupply() -> u256;
    fn balanceOf(account: ContractAddress) -> u256;
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(spender: ContractAddress, amount: u256) -> bool;
}

// 1 There is no initial allocation, all tokens are generated through minting.
// 2 Anyone can call the mint function of the contract.
// 3 A block can be minted every 50 seconds.
// 4 The reward for each block is fixed and will be halved after every 400,000 blocks.
// 5 Minting will stop when the total number of mints reaches 8,000,000,000.
#[contract]
mod Pepe {
    use super::IERC20;
    use cmp::min;
    use box::BoxTrait;
    use option::OptionTrait;
    use integer::{BoundedInt, TryInto, Into, Felt252IntoU256};
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::{get_block_timestamp, get_tx_info};
    use zeroable::Zeroable;
    use starknet::contract_address::ContractAddressZeroable;

    const DECIMAL_PART: u128 = 1000000000000000000_u128;

    // mint arguments, with below values, the halve time will be about 231 days 
    const BLOCK_TIME: u64 = 50_u64; // seconds
    const BLOCK_HALVE_INTERVAL: u64 = 400000_u64; // blocks

    const MAX_SUPPLY: u128 = 8000000000000000000000000000_u128; // tokens


    struct Storage {
        _name: felt252,
        _symbol: felt252,
        _total_supply: u256,
        _balances: LegacyMap<ContractAddress, u256>,
        _allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
        _start_time: u64,
        _mint_count: u64,

        // mint_candidates
        _mint_candidates_count: u64,
        _mint_candidates: LegacyMap<ContractAddress, u64>,
        _mint_candidates_index: LegacyMap<u64, ContractAddress>,
        _mint_flag: u64,
    }

    #[event]
    fn Transfer(from: ContractAddress, to: ContractAddress, value: u256) {}

    #[event]
    fn Approval(owner: ContractAddress, spender: ContractAddress, value: u256) {}

    #[event]
    fn Apply(candidate: ContractAddress, mint_flag: u64) {}
    fn RepeatApply(candidate: ContractAddress, mint_flag: u64) {}

    impl Pepe of IERC20 {
        fn name() -> felt252 {
            _name::read()
        }

        fn symbol() -> felt252 {
            _symbol::read()
        }

        fn decimals() -> u8 {
            18_u8
        }

        fn totalSupply() -> u256 {
            _total_supply::read()
        }

        fn balanceOf(account: ContractAddress) -> u256 {
            _balances::read(account)
        }

        fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256 {
            _allowances::read((owner, spender))
        }

        fn transfer(recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            _transfer(sender, recipient, amount);
            true
        }

        fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            _spend_allowance(sender, caller, amount);
            _transfer(sender, recipient, amount);
            true
        }

        fn approve(spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            _approve(caller, spender, amount);
            true
        }
    }

    #[constructor]
    fn constructor(name: felt252, symbol: felt252) {
        initializer(name, symbol);
    }

    #[view]
    fn name() -> felt252 {
        Pepe::name()
    }

    #[view]
    fn symbol() -> felt252 {
        Pepe::symbol()
    }

    #[view]
    fn decimals() -> u8 {
        Pepe::decimals()
    }

    #[view]
    fn totalSupply() -> u256 {
        Pepe::totalSupply()
    }

    #[view]
    fn balanceOf(account: ContractAddress) -> u256 {
        Pepe::balanceOf(account)
    }

    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256 {
        Pepe::allowance(owner, spender)
    }

    #[view]
    fn start_time() -> u64 {
        _start_time::read()
    }

    #[view]
    fn mint_count() -> u64 {
        _mint_count::read()
    }

    #[view]
    fn mint_candidates_count() -> u64 {
        _mint_candidates_count::read()
    }

    #[view]
    fn is_mint_candidate(candidate: ContractAddress) -> bool {
        if (available_mint_count() > 0) {
            return false;
        }
        _mint_candidates::read(candidate) == _mint_flag::read()
    }

    #[view]
    fn available_mint_count() -> u64 {
        let now = get_block_timestamp();
        let can_mint_count = (now - _start_time::read()) / BLOCK_TIME;
        let already_minted = _mint_count::read();
        can_mint_count - already_minted
    }

    #[view]
    fn block_time() -> u64 {
        BLOCK_TIME
    }

    #[view]
    fn max_supply() -> u256 {
        u256 { low: MAX_SUPPLY, high: 0 }
    }

    #[view]
    fn block_halve_interval() -> u64 {
        BLOCK_HALVE_INTERVAL
    }

    #[view]
    fn block_reward() -> u256 {
        let already_minted = _mint_count::read();
        let n = already_minted / BLOCK_HALVE_INTERVAL;
        if (n == 0_u64) {
            u256 { low: 10000000000000000000000_u128, high: 0_u128 }
        } else if (n == 1_u64) {
            u256 { low: 5000000000000000000000_u128, high: 0_u128 }
        } else if (n == 2_u64) {
            u256 { low: 2500000000000000000000_u128, high: 0_u128 }
        } else if (n == 3_u64) {
            u256 { low: 1250000000000000000000_u128, high: 0_u128 }
        } else if (n == 4_u64) {
            u256 { low: 625000000000000000000_u128, high: 0_u128 }
        } else if (n == 5_u64) {
            u256 { low: 312500000000000000000_u128, high: 0_u128 }
        } else if (n == 6_u64) {
            u256 { low: 156250000000000000000_u128, high: 0_u128 }
        } else if (n == 7_u64) {
            u256 { low: 78125000000000000000_u128, high: 0_u128 }
        } else if (n == 8_u64) {
            u256 { low: 39062500000000000000_u128, high: 0_u128 }
        } else if (n == 9_u64) {
            u256 { low: 19531250000000000000_u128, high: 0_u128 }
        } else {
            u256 { low: 10000000000000000000_u128, high: 0_u128 }
        }
    }

    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool {
        Pepe::transfer(recipient, amount)
    }

    #[external]
    fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
        Pepe::transferFrom(sender, recipient, amount)
    }

    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool {
        Pepe::approve(spender, amount)
    }

    #[external]
    fn increase_allowance(spender: ContractAddress, added_value: u256) -> bool {
        _increase_allowance(spender, added_value)
    }

    #[external]
    fn decrease_allowance(spender: ContractAddress, subtracted_value: u256) -> bool {
        _decrease_allowance(spender, subtracted_value)
    }

    #[external]
    fn apply_mint() {
        let recipient = get_caller_address();
        _try_mint();
        _add_candidate(recipient);
    }

    ///
    /// Internals
    ///

    #[internal]
    fn initializer(name_: felt252, symbol_: felt252) {
        _name::write(name_);
        _symbol::write(symbol_);
    }

    #[internal]
    fn _increase_allowance(spender: ContractAddress, added_value: u256) -> bool {
        let caller = get_caller_address();
        _approve(caller, spender, _allowances::read((caller, spender)) + added_value);
        true
    }

    #[internal]
    fn _decrease_allowance(spender: ContractAddress, subtracted_value: u256) -> bool {
        let caller = get_caller_address();
        _approve(caller, spender, _allowances::read((caller, spender)) - subtracted_value);
        true
    }

    #[internal]
    fn _add_candidate(recipient: ContractAddress) {

        let candidate_flag = _mint_candidates::read(recipient);
        let mint_flag = _mint_flag::read();
        // check if recipient is already a candidate
        if (candidate_flag != mint_flag) {
            let mint_candidates_count = _mint_candidates_count::read() + 1;
            _mint_candidates_count::write(mint_candidates_count);
            _mint_candidates::write(recipient, mint_flag);
            _mint_candidates_index::write(mint_candidates_count, recipient);
            Apply(recipient, mint_flag);
        } else {
            // already a candidate
            RepeatApply(recipient, mint_flag);
        }
    }

    #[internal]
    fn _clear_candidates() {
        _mint_candidates_count::write(0);
        _mint_flag::write(_mint_flag::read() + 1);
    }

    #[internal]
    fn _get_seed() -> u128 {
        let transaction_hash: u256 = get_tx_info().unbox().transaction_hash.into();
        let ts_felt: felt252 = get_block_timestamp().into();
        let block_timestamp: u256 = ts_felt.into();
        return (transaction_hash + block_timestamp).low;
    }

    #[internal]
    fn _try_mint() {

        let candidates_count = _mint_candidates_count::read();
        if (candidates_count == 0) {
            return ();
        }

        let available_count = available_mint_count();
        if (available_count == 0) {
            return ();
        }

        let max_supply = max_supply();
        let mint_times = min(available_count, candidates_count);
        let mut i: u64 = 0;
        // prevent overflow
        let mut seed = _get_seed() % 18446744073709551616;
        loop {
            // check mint times
            if (i >= mint_times) {
                break ();
            }
            i += 1;

            // check max supply
            let block_reward = block_reward();
            if (max_supply - _total_supply::read() < block_reward) {
                break ();
            }

            // use prng to get a random index
            seed = (seed * 1103515245 + 12345) % 2147483648;
            let seed_felt: felt252 = seed.into();
            let seed_u64: u64 = seed_felt.try_into().unwrap();
            let index: u64 = (seed_u64 % candidates_count) + 1;

            let recipient = _mint_candidates_index::read(index);
            _mint_count::write(_mint_count::read() + 1);
            _mint(recipient, block_reward);
        };

        _clear_candidates();
    }

    #[internal]
    fn _mint(recipient: ContractAddress, amount: u256) {
        assert(_total_supply::read() + amount <= max_supply(), 'max supply reached');
        _total_supply::write(_total_supply::read() + amount);
        _balances::write(recipient, _balances::read(recipient) + amount);
        Transfer(Zeroable::zero(), recipient, amount);
    }

    #[internal]
    fn _burn(account: ContractAddress, amount: u256) {
        assert(!account.is_zero(), 'Pepe: burn from 0');
        assert(_balances::read(account) >= amount, 'burn amount exceeds balance');

        _total_supply::write(_total_supply::read() - amount);
        _balances::write(account, _balances::read(account) - amount);
        Transfer(account, Zeroable::zero(), amount);
    }

    #[internal]
    fn _approve(owner: ContractAddress, spender: ContractAddress, amount: u256) {
        assert(!owner.is_zero(), 'Pepe: approve from 0');
        assert(!spender.is_zero(), 'Pepe: approve to 0');
        _allowances::write((owner, spender), amount);
        Approval(owner, spender, amount);
    }

    #[internal]
    fn _transfer(sender: ContractAddress, recipient: ContractAddress, amount: u256) {
        assert(!sender.is_zero(), 'Pepe: transfer from 0');
        assert(!recipient.is_zero(), 'Pepe: transfer to 0');
        _balances::write(sender, _balances::read(sender) - amount);
        _balances::write(recipient, _balances::read(recipient) + amount);
        Transfer(sender, recipient, amount);
    }

    #[internal]
    fn _spend_allowance(owner: ContractAddress, spender: ContractAddress, amount: u256) {
        let current_allowance = _allowances::read((owner, spender));
        if current_allowance != BoundedInt::max() {
            _approve(owner, spender, current_allowance - amount);
        }
    }
}
