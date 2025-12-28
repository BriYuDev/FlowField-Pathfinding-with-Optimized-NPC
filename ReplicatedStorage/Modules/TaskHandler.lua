-- code by Suphi Kaner (MY GREAT MAN)

-- this code basically just make threads pooling so threads can be reused
local threads = {};

local self = {}

function self:Spawn(func, ...)
	task.spawn(table.remove(threads) or Thread, func, ...);
end

function Thread(func, ...)
	func(...);
	while true do
		table.insert(threads, coroutine.running());
		Call(coroutine.yield());
	end
end

function Call(func, ...)
	func(...);
end

return self
