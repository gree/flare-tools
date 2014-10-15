# -*- coding: utf-8; -*-

$LOAD_PATH.unshift File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'flare/util/pretty_table'
class PrettyTableTest < Test::Unit::TestCase
  include Flare::Util::PrettyTable

  def test_pretty_table
    expect = <<EOF.strip
abc defghi      jklm
  1 foo_bar_baz 1.11
  2 foo         0.00
EOF
    table = Table.new
    row = Row.new
    row.add_column(Column.new('abc'))
    row.add_column(Column.new('defghi'))
    row.add_column(Column.new('jklm'))
    table.add_row(row)
    row = Row.new
    row.add_column(Column.new(1, :align => :right))
    row.add_column(Column.new('foo_bar_baz'))
    row.add_column(Column.new('1.11'))
    table.add_row(row)
    row = Row.new
    row.add_column(Column.new(2, :align => :right))
    row.add_column(Column.new('foo'))
    row.add_column(Column.new('0.00'))
    table.add_row(row)

    assert_equal(expect, table.prettify)
  end

  def test_column_separator
    expect = "abc\tdefghi\tjklm"

    row = Row.new(:separator => "\t")
    row.add_column(Column.new('abc'))
    row.add_column(Column.new('defghi'))
    row.add_column(Column.new('jklm'))

    assert_equal(expect, row.prettify(0))
  end
end
