$:.unshift File.join(File.dirname(__FILE__), "..")
require "skinny_spec"

module LuckySneaks
  module ControllerSpecHelpers # :nodoc:
    include LuckySneaks::CommonSpecHelpers
    include LuckySneaks::ControllerRequestHelpers
    include LuckySneaks::ControllerStubHelpers
    
    def self.included(base)
      base.extend ExampleGroupMethods
      base.extend ControllerRequestHelpers::ExampleGroupMethods
    end
    
  private
    def create_ar_class_expectation(name, method, argument = nil, options = {})
      args = []
      if [:create, :update].include?(@controller_method)
        args << (argument.nil? ? valid_attributes : argument)
      else
        args << argument unless argument.nil?
      end
      args << options unless options.empty?
      if args.empty?
        return_value = class_for(name).send(method)
        class_for(name).should_receive(method).and_return(return_value)
      else
        return_value = class_for(name).send(method, *args)
        class_for(name).should_receive(method).with(*args).and_return(return_value)
      end
    end
    
    def create_positive_ar_instance_expectation(name, method, *args)
      instance = instance_for(name)
      if args.empty?
        return_value = instance.send(method)
        instance.should_receive(method).and_return(true)
      else
        return_value = instance.send(method, *args)
        instance.should_receive(method).with(*args).and_return(true)
      end
    end
    
    # These methods are designed to be used at the example group [read: "describe"] level
    # to simplify and DRY up common expectations.
    module ExampleGroupMethods
      # Creates an expectation that the controller method calls <tt>ActiveRecord::Base#find</tt>.
      # Examples:
      # 
      #   it_should_find :foos                                 # => Foo.should_receive(:find).with(:all)
      #   it_should_find :foos, :all                           # An explicit version of the above
      #   it_should_find :foos, :conditions => {:foo => "bar"} # => Foo.should_receive(:find).with(:all, :conditions => {"foo" => "bar"}
      #   it_should_find :foo                                  # => Foo.should_recieve(:find).with(@foo.id.to_s)
      #   it_should_find :foo, :params => "id"                 # => Foo.should_receive(:find).with(params[:id].to_s)
      #   it_should_find :foo, 2                               # => Foo.should_receive(:find).with("2")
      # 
      # <b>Note:</b> All params (key and value) will be strings if they come from a form element and are handled
      # internally with this expectation.
      def it_should_find(name, *args)
        name_string = name.to_s
        name_message = if name_string == name_string.singularize
          "a #{name}"
        else
          name
        end
        it "should find #{name_message}" do
          options = args.extract_options!
          # Blech!
          argument = if param = params[options.delete(:params)]
            param.to_s
          else
            if args.first
              args.first
            elsif (instance = instance_variable_get("@#{name}")).is_a?(ActiveRecord::Base)
              instance.id.to_s
            else
              :all
            end
          end
          create_ar_class_expectation name, :find, argument, options
          eval_request
        end
      end

      def it_should_initialize(name, options = {})
        it "should initialize a #{name}" do
          create_ar_class_expectation name, :new, params[options.delete(:params)], options
          eval_request
        end
      end

      def it_should_save(name)
        it "should save the #{name}" do
          create_positive_ar_instance_expectation name, :save
          eval_request
        end
      end

      def it_should_update(name, options = {})
        it "should update the #{name}" do
          create_positive_ar_instance_expectation name, :update_attributes, params[options[:params]]
          eval_request
        end
      end

      def it_should_destroy(name, options = {})
        it "should delete the #{name}" do
          create_positive_ar_instance_expectation name, :destroy
          eval_request
        end
      end
      
      # Creates expectation[s] that the controller method should assign the specified 
      # instance variables along with any specified values. Examples:
      # 
      #   it_should_assign :foo               # => assigns[:foo].should == @foo
      #   it_should_assign :foo => "bar"      # => assigns[:foo].should == "bar"
      #   it_should_assign :foo => :nil       # => assigns[:foo].should be_nil
      #   it_should_assign :foo => :not_nil   # => assigns[:foo].should_not be_nil
      #   it_should_assign :foo => :undefined # => controller.send(:instance_variables).should_not include("@foo")
      # 
      # Very special thanks to Rick Olsen for the basis of this code. The only reason I even
      # redefine it at all is purely an aesthetic choice for specs like "it should foo"
      # over ones like "it foos".
      def it_should_assign(*names)
        names.each do |name|
          if name.is_a?(Symbol)
            it_should_assign name => name
          elsif name.is_a?(Hash)
            name.each do |key, value|
              it_should_assign_instance_variable key, value
            end
          end
        end
      end

      # Creates an expectation that the specified collection (<tt>flash</tt> or session)
      # contains the specified key and value
      def it_should_set(collection, key, value = nil, &block)
        it "should set #{collection}[:#{key}]" do
          eval_request
          if value
            self.send(collection)[key].should == value
          elsif block_given?
            self.send(collection)[key].should == block.call
          else
            self.send(collection)[key].should_not be_nil
          end
        end
      end
      
      # Wraps <tt>it_should_set :flash</tt>
      def it_should_set_flash(name, value = nil)
        it_should_set :flash, name, value
      end

      # Wraps <tt>it_should_set :session</tt>
      def it_should_set_session(name, value = nil)
        it_should_set :session, name, value
      end
      
      # Wraps the various <tt>it_should_render_<i>foo</i></tt> methods:
      # <tt>it_should_render_template</tt>, <tt>it_should_render_xml</tt>,
      # <tt>it_should_render_json</tt>, <tt>it_should_render_formatted</tt>,
      # and <tt>it_should_render_nothing</tt>.
      def it_should_render(render_method, *args)
        send "it_should_render_#{render_method}", *args
      end

      # Creates an expectation that the controller method renders the specified template.
      # Accepts the following options which create additional expectations.
      # 
      #   <tt>:content_type</tt>:: Creates an expectation that the Content-Type header for the response
      #                            matches the one specified
      #   <tt>:status</tt>::       Creates an expectation that the HTTP status for the response
      #                            matches the one specified
      def it_should_render_template(name, options = {})
        create_status_expectation options[:status] if options[:status]
        it "should render '#{name}' template" do
          eval_request
          response.should render_template(name)
        end
        create_content_type_expectation(options[:content_type]) if options[:content_type]
      end

      # Creates an expectation that the controller method renders the specified record via <tt>to_xml</tt>.
      # Accepts the following options which create additional expectations.
      # 
      #   <tt>:content_type</tt>:: Creates an expectation that the Content-Type header for the response
      #                            matches the one specified
      #   <tt>:status</tt>::       Creates an expectation that the HTTP status for the response
      #                            matches the one specified
      def it_should_render_xml(record = nil, options = {}, &block)
        it_should_render_formatted :xml, record, options, &block
      end

      # Creates an expectation that the controller method renders the specified record via <tt>to_json</tt>.
      # Accepts the following options which create additional expectations.
      # 
      #   <tt>:content_type</tt>:: Creates an expectation that the Content-Type header for the response
      #                            matches the one specified
      #   <tt>:status</tt>::       Creates an expectation that the HTTP status for the response
      #                            matches the one specified
      def it_should_render_json(record = nil, options = {}, &block)
        it_should_render_formatted :json, record, options, &block
      end

      # Called internally by <tt>it_should_render_xml</tt> and <tt>it_should_render_json</tt>
      # but should not really be called much externally unless you have defined your own
      # formats with a matching <tt>to_foo</tt> method on the record.
      # 
      # Which is probably never.
      def it_should_render_formatted(format, record = nil, options = {}, &block)
        create_status_expectation options[:status] if options[:status]
        it "should render #{format.inspect}" do
          if record.is_a?(Hash)
            options = record
            record = nil
          end
          if record.nil? && !block_given?
            raise ArgumentError, "it_should_render must be called with either a record or a block and neither was given."
          else
            if record
              pieces = record.to_s.split(".")
              record = instance_variable_get("@#{pieces.shift}")
              record = record.send(pieces.shift) until pieces.empty?
            end
            block ||= proc { record.send("to_#{format}") }
            get_response do |response|
              response.should have_text(block.call)
            end
          end
        end
        create_content_type_expectation(options[:content_type]) if options[:content_type]
      end

      # Creates an expectation that the controller method returns a blank page. You'd already 
      # know when and why to use this so I'm not typing it out.
      def it_should_render_nothing(options = {})
        create_status_expectation options[:status] if options[:status]
        it "should render :nothing" do
          get_response do |response|
            response.body.strip.should be_blank
          end
        end
      end
      
      # Creates an expectation that the controller method redirects to the specified destination. Example:
      # 
      #   it_should_redirect_to { foos_url }
      # 
      # <b>Note:</b> This method takes a block to evaluate the route in the example
      # context rather than the example group context.
      def it_should_redirect_to(hint = nil, &route)
        if hint.nil? && route.respond_to?(:to_ruby)
          hint = route.to_ruby.gsub(/(^proc \{)|(\}$)/, '').strip
        end
        it "should redirect to #{(hint || route)}" do
          eval_request
          response.should redirect_to(instance_eval(&route))
        end
      end
      
    private
      def it_should_assign_instance_variable(name, value)
        expectation_proc = case value
          when :nil
            proc { assigns[name].should be_nil }
          when :not_nil
            proc { assigns[name].should_not be_nil }
          when :undefined
            proc { controller.send(:instance_variables).should_not include("@{name}") }
          when Symbol
            if (instance_variable = instance_variable_get("@#{name}")).nil?
              proc { assigns[name].should_not be_nil }
            else
              proc { assigns[name].should == instance_variable }
            end
          else
            proc { assigns[name].should == value }
          end
        it "should #{value == :nil ? 'not ' : ''}assign @#{name}" do
          eval_request
          instance_eval &expectation_proc
        end
      end
    end
  end
end