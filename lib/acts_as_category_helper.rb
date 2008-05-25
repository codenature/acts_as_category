module ActsAsCategoryHelper
  
  def sortable_categories(model, ajaxurl = {:controller => :funkengallery, :action => :update_positions}, column = 'name')
    raise "Model '#{model.to_s}' does not acts_as_category" unless model.respond_to?(:acts_as_category)
    result = '<div id="sortable_category_response" "></div>'
    model.roots.each { |root| result += sortable_category_list(root, ajaxurl, column) }
    result
  end

  private
  
  def sortable_category_list(category, ajaxurl, column = 'name')
    parent_id = category.parent ? category.parent.id.to_s : '0'
    firstitem = category.read_attribute(category.position_column) == 1
    lastitem  = category.position == category.self_and_siblings.size
    result = ''
    result += "<ul id=\"sortable_categories_#{parent_id}\">\n" if firstitem
    result += "<li id=\"category_#{category.id}\">#{category.read_attribute(column)}"
    result += category.children.empty? ? "</li>\n" : "\n"
    category.children.each {|child| result += sortable_category_list(child, ajaxurl, column = 'name') } unless category.children.empty?
    result += "</ul></li>\n" + sortable_element("sortable_categories_#{parent_id}", :update => 'sortable_category_response', :url => ajaxurl) if lastitem
    result
  end

end
