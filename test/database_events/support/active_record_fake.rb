module ActiveRecordFake

  def self.included(base)
    base.instance_variable_set(:@items, [])
    base.instance_variable_set(:@next_id, 1)    
    base.extend(ClassMethods)
  end


  attr_accessor :id

  def initialize options={}
    @id = options.fetch(:id) { self.class.get_next_id }
    set_attribute_values_from_options options.reject{|key, value| key == :id }
    self.class.add self
  end

  def delete!
    self.class.remove(self)
  end

  def update options={}
    set_attribute_values_from_options options
  end

  def attributes
    Hash[instance_variables.map { |name| [name, instance_variable_get(name)] } ]
  end

  module ClassMethods
    def create *args
      new *args
    end
    
    def delete_all
      @items.clear
      reset_id
      true
    end

    def all
      @items.dup
    end
    
    
    def add instance
      @items << instance
    end

    def remove instance
      @items.delete(instance)
    end

    def get_next_id
      id = @next_id
      @next_id += 1
      id
    end

    def reset_id
      @next_id = 1
    end
  end

  private

    def set_attribute_values_from_options options
      options.each{|attr, value| self.send("#{attr}=".to_sym, value) }
    end
end