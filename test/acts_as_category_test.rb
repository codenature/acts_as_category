# Test for acts_as_category
#
# There are several ways to execute this test:
#
# 1. Open this file on a Mac in TextMate and press APPLE + R
# 2. Go to "vendor/plugins/acts_as_category/test" and run "rake test" in a terminal window
# 3. Run "rake test:plugins" in a terminal window to execute tests of all plugins
#
# For further information see http://blog.funkensturm.de/ruby-on-rails-plugins

require 'test/unit'
require 'rubygems'
require 'active_record'

class Test::Unit::TestCase
  def assert_queries(num = 1)
    $query_count = 0
    yield
  ensure
    assert_equal num, $query_count, "#{$query_count} instead of #{num} queries were executed."
  end

  def assert_no_queries(&block)
    assert_queries(0, &block)
  end
end

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

# AR keeps printing annoying schema statements
$stdout = StringIO.new

def setup_db
  ActiveRecord::Base.logger
  ActiveRecord::Schema.define(:version => 1) do
    create_table :mixins do |t|
      t.column :parent_id,         :integer
      t.column :position,          :integer
      t.column :children_count,    :integer
      t.column :ancestors_count,   :integer
      t.column :descendants_count, :integer
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

setup_db # Because the plugin needs an existing table before initialization (e.g. for attr_readonly)
$:.unshift File.dirname(__FILE__) + '/../lib' # make "lib" known to "require"
require 'active_record/acts/category'
require File.dirname(__FILE__) + '/../init' # Initialize Plugin

class Mixin < ActiveRecord::Base
end

class CategoryMixin < Mixin 
  acts_as_category
end

class CategoryMixinWithoutOrder < Mixin 
  acts_as_category :order => nil
end

teardown_db # Because CategoryTest's setup method won't execute setup_db otherwise

class CategoryTest < Test::Unit::TestCase
  
  # Test category trees:
  #
  #   r1                 r2                 r3
  #    \_ r11             \_ r21
  #         \_ r111       \    \_ r211
  #                       \_ r22
  #                            \_ r221
  def setup
    setup_db
    assert @r1   = CategoryMixin.create!
    assert @r2   = CategoryMixin.create!
    assert @r3   = CategoryMixin.create!
    assert @r11  = CategoryMixin.create!(:parent_id => @r1.id)
    assert @r21  = CategoryMixin.create!(:parent_id => @r2.id)
    assert @r22  = CategoryMixin.create!(:parent_id => @r2.id)
    assert @r111 = CategoryMixin.create!(:parent_id => @r11.id)
    assert @r211 = CategoryMixin.create!(:parent_id => @r21.id)
    assert @r221 = CategoryMixin.create!(:parent_id => @r22.id)
    assert @r1   = CategoryMixin.find(1)
    assert @r2   = CategoryMixin.find(2)
    assert @r3   = CategoryMixin.find(3)
    assert @r11  = CategoryMixin.find(4)
    assert @r21  = CategoryMixin.find(5)
    assert @r22  = CategoryMixin.find(6)
    assert @r111 = CategoryMixin.find(7)
    assert @r211 = CategoryMixin.find(8)
    assert @r221 = CategoryMixin.find(9)
    CategoryMixin.hidden = []
  end

  def teardown
    teardown_db
  end
  
  def check_cache
    CategoryMixin.find(:all).each { |c|
      # Note that "children_count" is a built-in Rails functionality and must not be tested here
      assert_equal c.ancestors.size,   c.ancestors_count
      assert_equal c.descendants.size, c.descendants_count
    }
  end
  
  def test_cache_columns
    check_cache
  end
  
  def test_attr_readonly
    assert @r1.children_count = 99
    assert @r1.ancestors_count = 99
    assert @r1.descendants_count = 99
    assert @r1.save
    assert @r1 = CategoryMixin.find(1)
    assert_nil @r1.children_count
    assert_equal 0, @r1.ancestors_count
    assert_equal 2, @r1.descendants_count
    assert_raises(NameError) { @r1.update_attribute(children_count, 99) }
    assert_raises(NameError) { @r1.update_attribute(ancestors_count, 99) }
    assert_raises(NameError) { @r1.update_attribute(descendants_count, 99) }
  end

  def test_children
    assert_equal [@r11], @r1.children
    assert_equal [@r21, @r22], @r2.children
    assert_equal [], @r3.children
    assert_equal [@r111], @r11.children
    assert_equal [], @r111.children
    assert_equal [@r211], @r21.children
    assert_equal [@r221], @r22.children
    assert_equal [], @r211.children
    assert_equal [], @r221.children
    CategoryMixin.hidden = [6,7]
    assert_equal [@r11], @r1.children
    assert_equal [@r21], @r2.children
    assert_equal [], @r3.children
    assert_equal [], @r11.children
    assert_equal [], @r111.children
    assert_equal [@r211], @r21.children
    assert_equal [@r221], @r22.children
    assert_equal [], @r211.children
    assert_equal [], @r221.children
  end
  
   def test_children_size
     assert_equal 1, @r1.children.size
     assert_equal 2, @r2.children.size
     assert_equal 0, @r3.children.size
     assert_equal 1, @r11.children.size
     assert_equal 0, @r111.children.size
     assert_equal 1, @r21.children.size
     assert_equal 1, @r22.children.size
     assert_equal 0, @r211.children.size
     assert_equal 0, @r221.children.size
     CategoryMixin.hidden = [6,7]
     assert_equal 1, @r1.children.size
     assert_equal 1, @r2.children.size
     assert_equal 0, @r3.children.size
     assert_equal 0, @r11.children.size
     assert_equal 0, @r111.children.size
     assert_equal 1, @r21.children.size
     assert_equal 1, @r22.children.size
     assert_equal 0, @r211.children.size
     assert_equal 0, @r221.children.size
  end
  
  def test_parent
    assert_nil @r1.parent
    assert_nil @r2.parent
    assert_nil @r3.parent
    assert_equal @r1, @r11.parent
    assert_equal @r11, @r111.parent
    assert_equal @r2, @r21.parent
    assert_equal @r2, @r22.parent
    assert_equal @r21, @r211.parent
    assert_equal @r22, @r221.parent
  end
  
  def test_ancestors
    assert_equal [], @r1.ancestors
    assert_equal [], @r2.ancestors
    assert_equal [], @r3.ancestors
    assert_equal [], @r3.ancestors_ids
    assert_equal [@r1], @r11.ancestors
    assert_equal [@r2], @r21.ancestors
    assert_equal [@r2], @r22.ancestors
    assert_equal [2], @r22.ancestors_ids
    assert_equal [@r11, @r1], @r111.ancestors
    assert_equal [@r21, @r2], @r211.ancestors
    assert_equal [@r22, @r2], @r221.ancestors
    assert_equal [6, 2], @r221.ancestors_ids
  end
  
  def test_descendants
    assert_equal [@r11, @r111], @r1.descendants
    assert_equal [@r21, @r211, @r22, @r221], @r2.descendants
    assert_equal [5, 8, 6, 9], @r2.descendants_ids
    assert_equal [], @r3.descendants
    assert_equal [], @r3.descendants_ids
    assert_equal [@r111], @r11.descendants
    assert_equal [@r211], @r21.descendants
    assert_equal [@r221], @r22.descendants
    assert_equal [9], @r22.descendants_ids
    assert_equal [9], @r22.descendants_ids
    assert_equal [], @r111.descendants
    assert_equal [], @r211.descendants
    assert_equal [], @r221.descendants
    assert_equal [], @r221.descendants_ids
  end
  
  def test_root
    assert_equal [@r1, @r2, @r3], CategoryMixin.roots
    assert_equal @r1, @r1.root
    assert_equal @r1, @r11.root
    assert_equal @r1, @r111.root
    assert_equal @r2, @r21.root
    assert_equal @r2, @r211.root
    assert_equal @r2, @r22.root
    assert_equal @r2, @r221.root
    assert_equal @r3, @r3.root
  end

  def test_roots
    assert_equal [@r1, @r2, @r3], CategoryMixin.roots
  end

  def test_siblings
    assert_equal [@r2, @r3], @r1.siblings
    assert_equal [@r1, @r3], @r2.siblings
    assert_equal [@r1, @r2], @r3.siblings
    assert_equal [], @r11.siblings
    assert_equal [@r22], @r21.siblings
    assert_equal [@r21], @r22.siblings
    assert_equal [], @r111.siblings
    assert_equal [], @r211.siblings
    assert_equal [], @r221.siblings
  end

  def test_self_and_siblings
    assert_equal [@r1, @r2, @r3], @r1.self_and_siblings
    assert_equal [@r1, @r2, @r3], @r2.self_and_siblings
    assert_equal [@r1, @r2, @r3], @r3.self_and_siblings
    assert_equal [@r11], @r11.self_and_siblings
    assert_equal [@r21, @r22], @r21.self_and_siblings
    assert_equal [@r21, @r22], @r22.self_and_siblings
    assert_equal [@r111], @r111.self_and_siblings
    assert_equal [@r211], @r211.self_and_siblings
    assert_equal [@r221], @r221.self_and_siblings
  end
  
  def test_destroy
    assert_equal 9, CategoryMixin.count
    assert @r1.destroy
    assert_equal 6, CategoryMixin.count
    check_cache
    assert @r211.destroy
    assert_equal 5, CategoryMixin.count
    check_cache
    assert @r21.destroy
    assert_equal 4, CategoryMixin.count
    check_cache
    assert @r22.destroy
    assert_equal 2, CategoryMixin.count
    check_cache
    assert @r2.destroy
    assert @r3.destroy
    assert_equal 0, CategoryMixin.count
    check_cache
  end
  
  def test_insert
    teardown_db
    setup_db
    assert @r1   = CategoryMixin.create!
    check_cache
    assert @r2   = CategoryMixin.create!
    check_cache
    CategoryMixin.new().save
    assert @r3 = CategoryMixin.find(3)
    check_cache
    assert @r11  = CategoryMixin.create!(:parent_id => @r1.id)
    check_cache
    CategoryMixin.new(:parent_id => @r2.id).save
    assert @r21 = CategoryMixin.find(5)
    check_cache
    assert @r22  = CategoryMixin.create!(:parent_id => @r2.id)
    check_cache
    CategoryMixin.new(:parent_id => @r11.id).save
    assert @r111 = CategoryMixin.find(7)
    check_cache
    assert @r211 = CategoryMixin.create!(:parent_id => @r21.id)
    check_cache
    assert @r221 = CategoryMixin.create!(:parent_id => @r22.id)
    check_cache
    @r12 = @r1.children.create
    check_cache
    assert @r12
    assert_equal @r12.parent, @r1
    assert @r1 = CategoryMixin.find(1)
    assert_equal 2, @r1.children.size
    assert @r1.children.include?(@r12)
    assert @r1.children.include?(@r11)
    check_cache
  end

  def test_update_where_root_becomes_child
    @r1.update_attributes(:parent_id => @r21.id)
    check_cache
  end
  
  def test_update_where_child_becomes_root
    @r111.update_attributes(:parent_id =>nil)
    check_cache
  end
  
  def test_update_where_child_switches_within_branch
    @r22.update_attributes(:parent_id => @r211.id)
    check_cache
  end
  
  def test_update_where_child_switches_branch
    @r221.update_attributes(:parent_id => @r11.id)
    check_cache
  end
  
  def test_invalid_parent_id_type
    assert !CategoryMixin.new(:parent_id => 0.0).save
    assert !CategoryMixin.new(:parent_id => 1.5).save
    assert !CategoryMixin.new(:parent_id => 0).save
    assert !CategoryMixin.new(:parent_id => 'string').save
  end
  
  def test_non_existant_foreign_key
    assert !CategoryMixin.new(:parent_id => 9876543210).save
    assert_raise(ActiveRecord::RecordInvalid) { CategoryMixin.create!(:parent_id => 9876543210) }
  end
  
  def test_category_becomes_its_own_parent
    assert !@r1.update_attributes(:parent_id => @r1.id)
    assert @r2.parent_id = @r2.id
    assert !@r2.save
  end
  
  def test_category_becomes_parent_of_descendant
    assert !@r1.update_attributes(:parent_id => @r11.id)
    assert !@r1.update_attributes(:parent_id => @r111.id)
    assert !@r11.update_attributes(:parent_id => @r111.id)
    assert @r2.parent_id = @r21.id
    assert !@r2.save
  end
  
  def test_set_get_is_hidden
    CategoryMixin.hidden = nil
    assert_equal false, @r1.hidden?
    assert_equal false, @r21.hidden?
    assert_equal [], CategoryMixin.hidden
    CategoryMixin.hidden = [nil]
    assert_equal [], CategoryMixin.hidden
    CategoryMixin.hidden = [0]
    assert_equal [], CategoryMixin.hidden
    CategoryMixin.hidden = 'string'
    assert_equal [], CategoryMixin.hidden
    CategoryMixin.hidden = [1]
    assert_equal true, @r1.hidden?
    assert_equal false, @r2.hidden?
    assert_equal false, @r21.hidden?
    assert_equal [1], CategoryMixin.hidden
    CategoryMixin.hidden = [1,2,3]
    assert_equal true, @r1.hidden?
    assert_equal true, @r1.hidden?
    assert_equal false, @r21.hidden?
    assert_equal [1,2,3], CategoryMixin.hidden
    CategoryMixin.hidden = [1,'string',3]
    assert_equal [1,3], CategoryMixin.hidden
    assert_equal [1,3], CategoryMixin.hidden    
  end
  
  def test_update_positions
    CategoryMixin.update_positions({'sortable_categories_0' => [3,1,2]})
    assert_equal 1, CategoryMixin.find(3).position
    assert_equal 2, CategoryMixin.find(1).position
    assert_equal 3, CategoryMixin.find(2).position
    CategoryMixin.update_positions({'sortable_categories_2' => [6,5]})
    assert_equal 1, CategoryMixin.find(6).position
    assert_equal 2, CategoryMixin.find(5).position
    assert_raise(::ArgumentError) { CategoryMixin.update_positions({'sortable_categories_2' => [1]}) }
    assert_raise(::ArgumentError) { CategoryMixin.update_positions({'sortable_categories_2' => [1,2,3]}) }
    assert_raise(::ArgumentError) { CategoryMixin.update_positions({'sortable_categories_2' => [5,6,7]}) }
    assert_raise(::ArgumentError) { CategoryMixin.update_positions({'sortable_categories_9876543210' => [1]}) }
    assert_raise(::ArgumentError) { CategoryMixin.update_positions({'sortable_categories_1' => [9876543210]}) }
  end

  def test_hidden_sql
    assert_equal '', CategoryMixin.hidden_sql
    CategoryMixin.hidden = [1]
    assert_equal ' id NOT IN (1) ', CategoryMixin.hidden_sql
    assert_equal ' AND id NOT IN (1) ', CategoryMixin.hidden_sql(true)
    CategoryMixin.hidden = [1,2]
    assert_equal ' id NOT IN (1,2) ', CategoryMixin.hidden_sql
    assert_equal ' AND id NOT IN (1,2) ', CategoryMixin.hidden_sql(true)
  end
  
  def test_hidden_with_root
    CategoryMixin.hidden = [1]
    assert_equal [@r2,@r3], CategoryMixin.roots
    CategoryMixin.hidden = [1,2,3]
    assert_equal [], CategoryMixin.roots
  end
  
  def test_hidden_with_children
    CategoryMixin.hidden = [4]
    assert_equal [], @r1.children
  end
  
  def test_z
    assert_equal @r1, CategoryMixin.get(1)
    CategoryMixin.hidden = [1]
    assert_nil CategoryMixin.get(1)
    assert_equal @r2, CategoryMixin.get(2)
  end

end

# There are methods, which use configuration['order'] that need to be tested
class CategoryTestWithoutOrder < Test::Unit::TestCase
  
  def setup
    setup_db
    @r1 = CategoryMixinWithoutOrder.create!
    @r2 = CategoryMixinWithoutOrder.create!
  end

  def teardown
    teardown_db
  end

  def test_get
    assert_equal @r1, CategoryMixinWithoutOrder.get(1)
  end

  def test_roots
    assert_equal [], [@r1, @r2] - CategoryMixinWithoutOrder.roots
  end
end 
