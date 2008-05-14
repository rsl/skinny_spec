module LuckySneaks
  # These methods are mostly just called internally by various other spec helper
  # methods but you're welcome to use them as needed in your own specs.
  module CommonSpecHelpers
    # Returns class for the specified name. Example:
    # 
    #   class_for("foo") # => Foo
    def class_for(name)
      name.to_s.classify.constantize
    end

    # Returns instance variable for the specified name. Example:
    # 
    #   instance_for("foo") # => @foo
    def instance_for(name)
      instance_variable_get("@#{name}")
    end
    
    # Wraps a matcher that checks if the receiver contains an <tt>A</tt> element (link) 
    # whose <tt>href</tt> attribute is set to the specified path.
    def have_link_to(path)
      have_tag("a[href='#{path}']")
    end
  end
end