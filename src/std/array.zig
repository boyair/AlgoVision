const std = @import("std");
const heap = @import("../heap/interface.zig");
pub const Array = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    items: usize = 0, // tracks how many items are inserted
    mem: []usize, // the heap memory of the values
    capacity: usize, // amount of memory allocated for array

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator, .mem = &[_]usize{}, .capacity = 0 };
    }

    pub fn deinit(self: *Self) void {
        heap.free(self.allocator, self.mem);
    }

    pub fn initWithCapacity(allocator: std.mem.Allocator, capacity: usize) Self {
        var list = Self{ .allocator = allocator, .mem = &[_]usize{}, .capacity = 0 };
        list.ensureMinCapacity(capacity);
        return list;
    }

    pub fn clearRetainingCapacity(self: *Self) void {
        self.items = 0;
    }

    pub fn insert(self: *Self, item: i64) void {
        //handle case where no memory left for new item
        ensureMinCapacity(self, self.items + 1);
        //add the last item to the array
        self.items += 1;
        heap.set(self.mem[self.items - 1], item);
    }
    pub fn ensureMinCapacity(self: *Self, capacity: usize) void {
        if (capacity <= self.capacity) return;
        //change capacity value
        self.capacity = capacity;
        //recreate the array with new capacity
        const new_items = heap.allocate(self.allocator, self.capacity);
        //copy items from old array to new array
        for (self.mem, new_items[0..self.mem.len]) |old_itm, new_itm| {
            heap.set(new_itm, heap.get(old_itm));
        }
        //free old array
        heap.free(self.allocator, self.mem);
        self.mem = new_items;
    }
};
