const std = @import("std");
const AV = @import("AlgoVision");
var gpa = std.heap.GeneralPurposeAllocator(.{}){}; // allocator required for algovision heap allocations.
var cache: []usize = undefined; //cache is global so that fib function can access it.

pub fn main() !void {
    //initiallize AlgoVision
    try AV.init();
    defer AV.start() catch unreachable;

    //here is example code for how an algorithm that calculates
    //the fibonacci sequence (fib) recursively with caching looks like:

    const num = 13; // the number we will calculate the fib of
    cache = AV.heap.allocate(gpa.allocator(), num); // allocate array of size num for cache.

    //set all the cache to -1 to be able to know which values have not been cached yet
    for (cache) |idx| {
        AV.heap.set(idx, -1);
    }
    const result = AV.stack.call(fib, num);
    AV.log("fibonacci's {d}th element is: {d}\n", .{ num, result });
}

//each function called by algovision must return an i64 but can take any type as paremeter
fn fib(num: i64) i64 {
    if (num <= 1) return num; // base case

    const cache_idx: usize = @intCast(num - 1);
    //skip recursion if value found in cache
    //(if you want to see what it would look like without caching remove thiis section)
    const cache_value = AV.heap.get(cache[cache_idx]);
    if (cache_value != -1)
        return cache_value;

    //calculate fib recursively
    const result = AV.stack.call(fib, num - 1) + AV.stack.call(fib, num - 2);
    //set result in cache for future use.
    AV.heap.set(cache[cache_idx], result);
    return result;
}
