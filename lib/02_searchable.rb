require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)

    p params
    where_line = []
    params.map do |attr, val|
      where_line << "#{attr} = ?"
    end
    where_line = where_line.join("AND ")

    p where_line

    values_arr = params.values
    results = DBConnection.execute2(<<-SQL, values_arr)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{where_line}
    SQL

    results.shift

    self.parse_all_arr(results)

  end
end

class SQLObject
  extend Searchable
  # Mixin Searchable here...
end
