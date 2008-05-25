ActiveRecord::Base.send :include, ActiveRecord::Acts::Category
ActionView::Base.send :include, ActsAsCategoryHelper
