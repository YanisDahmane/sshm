require "zlib"

# PostgreSQL advisory locks held for the length of a block, on the current
# connection, so that two processes (two workers, a worker and a request)
# never run the same thing at the same time. The key includes the database
# name: the locks are shared by every database of a PostgreSQL server (the
# parallel test databases, two installations on the same server).
#
#   AdvisoryLock.try("automation:vulnerabilities_update") { … }  # skipped if held
#   AdvisoryLock.hold("vulnerability_feed:debian") { … }          # waits for it
module AdvisoryLock
  # Returned by try when another process holds the lock.
  HELD = Object.new.freeze

  def self.try(name)
    connection = ActiveRecord::Base.connection
    key = key(connection, name)
    return HELD unless connection.select_value(sql("pg_try_advisory_lock", key))

    begin
      yield
    ensure
      connection.execute(sql("pg_advisory_unlock", key))
    end
  end

  def self.hold(name)
    connection = ActiveRecord::Base.connection
    key = key(connection, name)
    connection.execute(sql("pg_advisory_lock", key))
    begin
      yield
    ensure
      connection.execute(sql("pg_advisory_unlock", key))
    end
  end

  def self.key(connection, name) = Zlib.crc32("#{connection.current_database}:#{name}")

  FUNCTIONS = %w[pg_try_advisory_lock pg_advisory_lock pg_advisory_unlock].freeze

  def self.sql(function, key)
    raise ArgumentError, function unless FUNCTIONS.include?(function)

    ActiveRecord::Base.sanitize_sql_array([ "SELECT #{function}(?)", key ])
  end
  private_class_method :sql
end
