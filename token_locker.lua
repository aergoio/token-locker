--[[

TokenLocker v1

To use:

  Transfer tokens to this contract, and specify the period to
  lock them as an argument in the transfer function.
  The period is in seconds.

  Example:

  contract.call(token, "transfer", token_locker, amount, period)

]]

state.var {
  locks = state.map(),     -- address (user)  -> list of locks
  per_token = state.map()  -- address (token) -> list of locks
}

-- A internal type check function
-- @type internal
-- @param x variable to check
-- @param t (string) expected type
local function _typecheck(x, t)
  if (x and t == 'address') then
    assert(type(x) == 'string', "address must be string type")
    -- check address length
    assert(52 == #x, string.format("invalid address length: %s (%s)", x, #x))
    -- check character
    local invalidChar = string.match(x, '[^123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]')
    assert(nil == invalidChar, string.format("invalid address format: %s contains invalid char %s", x, invalidChar or 'nil'))
  elseif (x and t == 'ubig') then
    -- check unsigned bignum
    assert(bignum.isbignum(x), string.format("invalid type: %s != %s", type(x), t))
    assert(x >= bignum.number(0), string.format("%s must be positive number", bignum.tostring(x)))
  else
    -- check default lua types
    assert(type(x) == t, string.format("invalid type: %s != %s", type(x), t or 'nil'))
  end
end

function tokensReceived(operator, from, amount, period)
  _typecheck(from, 'address')
  _typecheck(amount, 'ubig')

  -- the contract calling this function
  local token = system.getSender()

  -- who sent the tokens
  local account = from

  -- convert the amount to bignumber
  assert(bignum.compare(amount, 0) > 0, "the amount must be positive")

  -- convert the period to number
  if type(period) ~= 'number' then
    period = tonumber(period)
  end

  local lock = {
    amount = amount,
    token = token,
    expiration_time = system.getTimestamp() + period
  }

  -- check if this account already have any locked tokens
  local account_locks = locks[account]
  if account_locks == nil then
    account_locks = {}
  end

  -- add the new lock to the list (use an array of tables)
  table.insert(account_locks, lock)

  -- save it
  locks[account] = account_locks


  -- update the list of locks for this token

  local lock2 = {
    amount = amount,
    account = account,
    expiration_time = lock["expiration_time"]
  }

  -- check if this token already have any locks
  local token_locks = per_token[token]
  if token_locks == nil then
    token_locks = {}
  end

  -- add the new lock to the list (use an array of tables)
  table.insert(token_locks, lock2)

  -- save it
  per_token[token] = token_locks

end

function locks_per_account(account)
  if account == nil then
    account = system.getSender()
  else
    _typecheck(account, 'address')
  end
  local account_locks = locks[account]
  return json.encode(account_locks)
end

function locks_per_token(token)
  _typecheck(token, 'address')
  local token_locks = per_token[token]
  return json.encode(token_locks)
end

-- return the total amount that is really locked,
-- ie, in which the lock has not expired
function get_total_locked(token)
  _typecheck(token, 'address')
  local token_locks = per_token[token]
  if token_locks == nil then
    return bignum.number(0)
  end
  local now = system.getTimestamp()
  local total_locked = bignum.number(0)
  for _,lock in ipairs(token_locks) do
    if lock["expiration_time"] > now then
      --total_locked = total_locked + lock["amount"]
      total_locked:add(lock["amount"])
    end
  end
  return bignum.tostring(total_locked)
end

function withdraw(index)

  -- transaction signer or contract
  local account = system.getSender()

  -- get the locked tokens from this account
  local account_locks = locks[account]
  assert(account_locks ~= nil, "no locked tokens for this account")

  -- get the locked tokens at the given index
  if index == nil then
    index = 1
  end
  local lock = account_locks[index]
  assert(lock ~= nil, "no locked tokens at this index")

  -- check if the tokens are unlocked
  assert(lock["expiration_time"] <= system.getTimestamp(), "these tokens are locked until " .. lock["expiration_time"] .. ". now is " .. system.getTimestamp())

  local token = lock["token"]
  local amount = lock["amount"]

  -- update the state BEFORE any external call to avoid reentrancy attack

  -- are there more than 1 lock for this account?
  if #account_locks > 1 then
    -- remove the lock from the list
    table.remove(account_locks, index)
    -- save the updated list
    locks[account] = account_locks
  else
    -- no more locks for this account
    locks:delete(account)
  end

  -- update the list of locks for this token

  local token_locks = per_token[token]

  -- are there more than 1 lock for this account?
  if #token_locks > 1 then
    for index,lock2 in ipairs(tolen_locks) do
      if lock2["expiration_time"] == lock["expiration_time"] and
         lock2["account"] == account and
         lock2["amount"] == amount then
        -- remove the lock from the list
        table.remove(token_locks, index)
        -- save the updated list
        per_token[token] = token_locks
        break
      end
    end
  else
    -- no more locks for this token
    per_token:delete(token)
  end

  -- transfer the tokens
  contract.call(token, "transfer", account, amount)

end

abi.register(tokensReceived, withdraw)
abi.register_view(locks_per_account, locks_per_token, get_total_locked)
