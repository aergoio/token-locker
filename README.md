# Aergo Token Locker :lock:

The Token Locker is a contract used to lock tokens for a specified
amount of time

The user/team cannot withdraw the tokens before that time expires

The user/team can also prove that the tokens are locked for that
time

By knowing the total supply of a token and subtracting the total
locked amount we can calculate the circulating supply


# Token Locker Address

<table>
  <tr><td>mainnet</td><td>Amg5nZV4qsjSYaageL13gZ2ohc4vdz6JQuVaYHaNnG3o1sBT5bVL</td></tr>
  <tr><td>testnet</td><td>AmhXTtDUv7ZCJHB8Bz29S5F8pEj5F6gmb6wGLzUn7ADwergXNJAc</td></tr>
  <tr><td>alphanet</td><td>AmhAvnBPJFhocdon7icguc5Yerd9amHqnVTeJ8bK2tr227pnh2X3</td></tr>
</table>


# Usage

Transfer tokens to this contract, and specify the period to
lock them as an argument in the transfer function.

It is also possible to transfer the tokens to another account and
have them locked for a period. Use the last (optional) argument
for this purpose. In this case the user will only be able to withdraw
the tokens after the locking period.

Example:

```lua
contract.call(token, "transfer", token_locker, amount, period, recipient)
```

Where:

* `token` is the address of the given token to be locked
* `token_locker` is the address of this contract
* `amount` is the amount of tokens to be locked, as bignum
* `period` is the amount of time to lock the tokens
* `recipient` is the address of the recipient, used when lock-transferring tokens (optional)

The `period` can be either the an integer representing the number
of seconds or a string starting with "on " and a unix timestamp
in seconds, like this: "on 1742070600"


## Locking Aergo Tokens

In this case we use the WAERGO token contract

Instead of `transfer` we use `wrap_to`, and we must send the aergo
tokens to the contract

```lua
contract.call.value(amount)(waergo, "wrap_to", token_locker, period)
```

Where `waergo` is the address of the WAERGO contract


## Withdraw

Call the `withdraw` function

If your account has more than one lock, specify the index (integer)
of the token lock to be withdrawn (base 1).

```lua
contract.call(token_locker, "withdraw", index)
```

If you don't know the index, retrieve the list of tokens for
your account (check bellow).

If you only have 1 lock, then you can let the argument empty.

```lua
contract.call(token_locker, "withdraw")
```

If you have locked aergo token then you will receive WAERGO back. To
convert to native tokens just use the `unwrap` function on the
WAERGO contract.


## Locked Tokens per Account

To get the list of locked tokens for an account, use the
`locks_per_account` function, passing the account address as the
argument.

```lua
local list = contract.call(token_locker, "locks_per_account", user_address)
```

If retrieving for your own account, just let the argument empty (nil).

It returns a JSON array with information about each lock.


## Locks per Token

To get the list of locks for a token, use the
`locks_per_token` function, passing the token address as the
argument.

```lua
local list = contract.call(token_locker, "locks_per_token", token_address)
```

It returns a JSON array with information about each lock.


## Total Locked Amount per Token

To discover the total locked amount for a specific token we use the
`get_total_locked` function, passing the token address as the argument.

```lua
local total_locked = contract.call(token_locker, "get_total_locked", token_address)
```
