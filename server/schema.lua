KoraMultijobSchema = {
    {
        name = 'kora_multijob_jobs',
        columns = {
            { name = 'citizenid', type = 'varchar(64)' },
            { name = 'name', type = 'varchar(128)', default = 'unknown' },
            { name = 'jobs', type = 'longtext' },
            { name = 'updated_at', type = 'timestamp', default = { raw = 'CURRENT_TIMESTAMP' }, on_update = 'CURRENT_TIMESTAMP' },
        },
        primary = { 'citizenid' },
    },
}
