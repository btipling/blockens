const zjobs = @import("zjobs");

const AllJobs = zjobs.JobQueue(.{
    .max_threads = 4,
    .idle_sleep_ns = 100,
});
var all_jobs = AllJobs.init();

pub const Jobs = struct {
    pub fn start() void {
        all_jobs.start();
    }
};
