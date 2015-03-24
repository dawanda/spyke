require 'spyke/associations/association'
require 'spyke/associations/builder'
require 'spyke/associations/has_many'
require 'spyke/associations/has_one'
require 'spyke/associations/belongs_to'

module Spyke
  module Associations
    extend ActiveSupport::Concern

    included do
      class_attribute :associations
      self.associations = {}.freeze
    end

    module ClassMethods
      def has_many(name, options = {})
        install_association(name, HasMany, options)

        define_method "#{name.to_s.singularize}_ids=" do |ids|
          attributes[name] = []
          ids.reject(&:blank?).each { |id| association(name).build(id: id) }
        end

        define_method "#{name.to_s.singularize}_ids" do
          association(name).map(&:id)
        end
      end

      def has_one(name, options = {})
        install_association(name, HasOne, options)
        define_singular_constructors(name)
      end

      def belongs_to(name, options = {})
        install_association(name, BelongsTo, options)
        define_singular_constructors(name)
      end

      def accepts_nested_attributes_for(*names)
        names.each do |association_name|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{association_name}_attributes=(association_attributes)
              association(:#{association_name}).assign_nested_attributes(association_attributes)
            end
          RUBY
        end
      end

      def reflect_on_association(name)
        # Just enough to support nested_form gem
        associations[name] || associations[name.to_s.pluralize.to_sym]
      end

      private

        def install_association(name, type, options)
          self.associations = associations.merge(name => Builder.new(self, name, type, options))
        end

        def define_singular_constructors(name)
          define_method "build_#{name}" do |attributes = nil|
            association(name).build(attributes)
          end

          define_method "create_#{name}" do |attributes = nil|
            record = send("build_#{name}", attributes)
            record.save
            record
          end
        end
    end
  end
end
