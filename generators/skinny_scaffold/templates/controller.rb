class <%= controller_class_name %>Controller < ApplicationController
  make_resourceful do
    actions :all
    
    # Let's get the most use from form_for and share a single form here!
    response_for :new, :create_fails, :edit, :update_fails do
      render :template => "<%= plural_name %>/form"
    end
  end
end
