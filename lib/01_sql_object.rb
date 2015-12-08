require_relative 'db_connection'
require 'active_support/inflector'

# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject

  def self.columns

    results = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{ self.table_name }
    SQL

    results.first.map { |column_name| column_name.to_sym }
  end

  def self.finalize!
    symbol_column_names = self.columns

    symbol_column_names.each do |col_name|

      define_method(col_name) do
        self.attributes[col_name]
      end

      define_method("#{ col_name }=") do |new_col_name|
        self.attributes[col_name] = new_col_name
      end

    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
    # self.instance_variable_set("@table_name".to_sym, table_name)
  end

  def self.table_name
    @table_name || self.to_s.tableize
  end

  def self.all
    results = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{ self.table_name }
    SQL

    results.shift

    self.parse_all(results)

  end

  def self.parse_all(results)
    objects = []
    results.each do |hash|
      objects << self.new(hash)
    end
    if objects.length < 2
      return objects.first
    else
      return objects
    end

  end

  def self.parse_all_arr(results)
    results.map {|hash| self.new(hash)}
  end

  def self.find(id)
    results = DBConnection.execute2(<<-SQL, id)
      SELECT
        *
      FROM
        #{ self.table_name }
      WHERE
        id = ?
    SQL
    results.shift

    self.parse_all(results)
  end

  def initialize(params = {})

    params.each do |attr, val|
      attr = attr.to_sym
      if self.class.columns.include?(attr)
        self.send("#{ attr }=", val)
      else
        raise "unknown attribute '#{ attr }'"
      end
    end

  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map { |col| self.send(col) }
  end

  def insert

    col_names = self.class.columns.join(", ")
    question_marks = []

    (self.class.columns.length).times do
      question_marks << "?"
    end

    question_marks = question_marks.join(",")
    question_marks = "(#{ question_marks })"
    insert = "#{ self.class.table_name } (#{ col_names })"

    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{ insert }
      VALUES
        #{ question_marks }
    SQL
    self.id = DBConnection.last_insert_row_id

    nil
  end

  def update
    set = ""
    col_names = self.class.columns

    col_names.each do |cname|
      set << "#{ cname } = ?, "
    end
    set = set.chomp(', ')

    result = DBConnection.execute(<<-SQL, attribute_values, self.id)
      UPDATE
        #{ self.class.table_name }
      SET
        #{ set }
      WHERE
        id = ?
    SQL

    result
  end

  def save
    if id.nil?
      insert
    else
      update
    end
  end
end
