return {
    -- Returns the monotonic time the system has been up, in secconds.
    monotime = function()
        return os.clock()
    end,

    -- Sleep for n seconds.
    sleep = function(n)
        os.sleep(n)
    end,

    -- Returns the current system time, 1970 (UTC), in secconds.
    gettime = function()
        return os.epoch('utc') / 1000
    end,
}
