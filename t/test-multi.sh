DBI_DSN='' make test
DBI_DSN='dbi:mysql:test:www.blackdart.com' make test
DBI_DSN='dbi:AnyData:test_data' make test
DBI_DSN='dbi:SQLite:dbname=t/test_data/test.sqlite' make test
DBI_DSN='dbi:CSV:f_dir=t/test_data' make test
