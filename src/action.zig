pub fn action(storage_type: type) type {
    return struct {
        do: fn (data: storage_type) void,
        undo: fn () void,
        setCache: fn (data: storage_type) storage_type,
        cache: storage_type,
    };
}
