--[[

TokenLocker v1

To use:

  Transfer tokens to this contract, and specify the period to
  lock them as an argument in the transfer function.
  The period is either the number of seconds or a string like
  "on 2530902665".

  Example:

  contract.call(token, "transfer", token_locker, amount, period)

]]

state.var {
  _user_locks = state.map(),  -- address (user)  -> list of locks
  _token_locks = state.map()  -- address (token) -> list of locks
}

-- A internal type check function
-- @type internal
-- @param x variable to check
-- @param t (string) expected type
local function _typecheck(x, t)
  if (x and t == 'address') then
    assert(type(x) == 'string', "the address must be in string format")
    -- check address length
    assert(#x == 52, string.format("invalid address length: %s (%s)", x, #x))
    -- check character
    local invalidChar = string.match(x, '[^123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]')
    assert(invalidChar == nil, string.format("invalid address format: %s contains invalid char %s", x, invalidChar or 'nil'))
  elseif (x and t == 'ubig') then
    -- check unsigned bignum
    assert(bignum.isbignum(x), string.format("invalid type: %s != %s", type(x), t))
    assert(x >= bignum.number(0), string.format("%s must be positive number", bignum.tostring(x)))
  elseif (x and t == 'uint') then
    -- check unsigned integer
    assert(type(x) == 'number', string.format("invalid type: %s != number", type(x)))
    assert(math.floor(x) == x, "the number must be an integer")
    assert(x >= 0, "the number must be 0 or positive")
  else
    -- check default lua types
    assert(type(x) == t, "expected %s but got %s", t, type(x))
  end
end

function tokensReceived(operator, from, amount, period, to)
  _typecheck(from, 'address')
  _typecheck(amount, 'ubig')

  -- the contract calling this function
  local token = system.getSender()

  -- who sent the tokens
  local account = from
  -- if there is a destination (locked transfer)
  if to ~= nil then
    _typecheck(to, 'address')
    account = to
  end

  -- the lock period
  local expiration_time = 0
  if type(period) == 'string' and period:sub(1,3) == "on " then
    expiration_time = tonumber(period:sub(4))
    assert(expiration_time > system.getTimestamp(), "the fire time must be in the future")
  else
    if type(period) ~= 'number' then
      period = tonumber(period)
    end
    assert(period > 0, "the period must be positive")
    -- calculate the fire time
    expiration_time = system.getTimestamp() + period
  end

  -- convert the amount to string
  amount = bignum.tostring(amount)

  local lock = {
    amount = amount,
    token = token,
    expiration_time = expiration_time
  }

  -- check if this account already have any locked tokens
  local account_locks = _user_locks[account]
  if account_locks == nil then
    account_locks = {}
  end

  -- add the new lock to the list (use an array of tables)
  table.insert(account_locks, lock)

  -- save it
  _user_locks[account] = account_locks


  -- update the list of locks for this token

  local lock2 = {
    amount = amount,
    account = account,
    expiration_time = expiration_time
  }

  -- check if this token already have any locks
  local token_locks = _token_locks[token]
  if token_locks == nil then
    token_locks = {}
  end

  -- add the new lock to the list (use an array of tables)
  table.insert(token_locks, lock2)

  -- save it
  _token_locks[token] = token_locks

end

function locks_per_account(account)
  if account == nil then
    account = system.getSender()
  else
    _typecheck(account, 'address')
  end
  local account_locks = _user_locks[account]
  return account_locks
end

function locks_per_token(token)
  _typecheck(token, 'address')
  local token_locks = _token_locks[token]
  return token_locks
end

-- return the total amount that is really locked.
-- ie: in which the lock has not yet expired
function get_total_locked(token)
  _typecheck(token, 'address')
  local token_locks = _token_locks[token]
  if token_locks == nil then
    return "0"
  end
  local now = system.getTimestamp()
  local total_locked = bignum.number(0)
  for _,lock in ipairs(token_locks) do
    if lock["expiration_time"] > now then
      total_locked = total_locked + bignum.number(lock["amount"])
    end
  end
  return bignum.tostring(total_locked)
end

function withdraw(index)

  -- transaction signer or contract
  local account = system.getSender()

  -- get the locked tokens from this account
  local account_locks = _user_locks[account]
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
    _user_locks[account] = account_locks
  else
    -- no more locks for this account
    _user_locks:delete(account)
  end

  -- update the list of locks for this token

  local token_locks = _token_locks[token]

  -- are there more than 1 lock for this account?
  if #token_locks > 1 then
    for index,lock2 in ipairs(token_locks) do
      if lock2["expiration_time"] == lock["expiration_time"] and
         lock2["account"] == account and
         lock2["amount"] == amount then
        -- remove the lock from the list
        table.remove(token_locks, index)
        -- save the updated list
        _token_locks[token] = token_locks
        break
      end
    end
  else
    -- no more locks for this token
    _token_locks:delete(token)
  end

  -- transfer the tokens
  contract.call(token, "transfer", account, amount)

end

abi.register(tokensReceived, withdraw)
abi.register_view(locks_per_account, locks_per_token, get_total_locked)
