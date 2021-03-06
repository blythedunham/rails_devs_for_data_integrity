# Rails Devs For Data Integrity catches unique key and foreign key violations
# coming from the  MySQLdatabase and converts them into an error on the
# ActiveRecord object similar to validation errors
#
#  class User < ActiveRecord::Base
#    handle_unique_key_violation  :user_name, :message => 'is taken"
#    handle_foreign_key_violation :primary_email_id, :message => 'is not available'
#  end
#
# Instead of this nasty MySQL foreign key error:
#  ActiveRecord::StatementInvalid: Mysql::Error: Cannot add or update a child row:
#  a foreign key constraint fails (`zoo_development/animals`,
#  CONSTRAINT `fk_animal_species` FOREIGN KEY (`species_id`)
#  REFERENCES `species` (`id`) ON DELETE SET NULL ON UPDATE CASCADE)
#
#  >> user.errors.on(:user_name)
#  => "association does not exist."
#
# Or in the case of a unique key violation:
#
#   >> user.errors.on(:primary_email_id)
#   => "is a duplicate."
# ==== Developers
# * Blythe Dunham http://snowgiraffe.com
#
# === Install
# * Rdoc:           http://snowgiraffe.com/rdocs/rails_devs_for_data_integrity
# * Github Project: http://github.com/blythedunham/rails_devs_for_data_integrity/tree/master
# * Install:        script/plugin install git://github.com/blythedunham/rails_devs_for_data_integrity.git

module ActiveRecord::RailsDevsForDataIntegrity

  def self.included(base)#:nodoc
    base.send :class_inheritable_hash, :unique_key_check_options
    base.send :class_inheritable_hash, :foreign_key_check_options
    base.send :class_inheritable_hash, :default_violation_messages

    base.send :attr_reader,            :duplicate_exception
    base.send :attr_reader,            :foreign_key_exception

    base.unique_key_check_options   = {}
    base.foreign_key_check_options  = {}
    base.default_violation_messages = {
      :taken           => 'has already been taken',
      :taken_multiple  => "has already been taken for {{context}}",
      :taken_generic   => 'Duplicate field.',
      :foreign_key     => "association does not exist."
    }
    base.extend ClassMethods
  end

  module ClassMethods
    # Handle a MySQL unique key violation by placing an error message on +name+
    # Currently only one duplicate key per table is supported because no parsing support
    # to determine the violating key
    #
    # +name+ - the field name of the duplicate key.
    #
    # == Options
    # <tt>:message</tt> - custom message. Defaults 'is not unique'.
    #
    # == Example
    #  class User < ActiveRecord::Base
    #    handle_unique_key_violation :user_name, :message => 'is taken"
    #  end
    def handle_unique_key_violation(*args)
      alias_data_integrity_methods
      options = args.extract_options! || {}
      options.symbolize_keys!
      args.each do |name|
        self.unique_key_check_options[ name.to_sym ]= options.merge(
          :field_name => name.to_s,
          :columns => [name.to_s].
            concat( (options[:scope]||[]).collect(&:to_s) ).uniq.sort
        )
      end
    end

    # Handle a MySQL foreign key violation by placing an error message on violating
    # foreign key field
    #
    # +name+ - the field name of the duplicate key.
    #
    # == Options
    # <tt>:message</tt> - custom message. Defaults 'association does not exist'.
    #
    # == Example
    #  class User < ActiveRecord::Base
    #    handle_foreign_key_violation :primary_email_id, :message => 'is does not exist"
    #  end
    def handle_foreign_key_violation(name, options={})
      alias_data_integrity_methods
      self.foreign_key_check_options = {name.to_sym => options}
    end

    # Handle a MySQL foreign key violations by placing an error message on violating
    # foreign key field
    #
    # <tt>:message</tt> - custom message. Defaults 'association does not exist'.
    #== Options
    # Options are a hash of foreign_key field name to options (messages). Without options
    # all violations use the default.
    #
    # == Example
    #  class User < ActiveRecord::Base
    #    handle_foreign_key_violations :primary_email_id => {:message => 'is does not exist"}
    #  end
    def handle_foreign_key_violations(options={})
      self.foreign_key_check_options = options
      alias_data_integrity_methods
    end

    #enable uniqueness and foreign key checks for all ActiveRecord instances
    def enable_all_database_violation_checks
      ActiveRecord::Base.alias_data_integrity_methods
    end

    protected

    #alias insert and update methods
    def alias_data_integrity_methods#:nodoc:
      return if method_defined?( :save_without_data_integrity_check! )
      alias_method_chain :create_or_update, :data_integrity_check
      alias_method_chain :save!, :data_integrity_check
    end
  end

  def default_error_message_for_violation( violation_type, columns )#:nodoc:
    message_key = if violation_type == :foreign_key
      :foreign_key
    else
      case columns.length
        when 0 then :taken_generic
        when 1 then :taken
        else :taken_multiple
      end
    end
    I18n.translate(
      :"activerecord.errors.messages.#{message_key}",
      :default => default_violation_messages[ message_key ],
      :context => columns.slice(1..-1).join('/')
    )
  end

  # Custom error messages set with handle_violation
  def custom_error_message_for_violation( violation_type, columns )#:nodoc:
    options = send(
      "#{violation_type}_check_options"
    )[ columns.first.to_sym ] if columns.any?

    message = case options[:message]
      when Symbol then Il8n.translate( options[:message] )
      else options[:message]
    end unless options.blank?
  end

  # Return the error message
  def error_message_for_violation( violation_type, columns )#:nodoc:
    message = custom_error_message_for_violation( violation_type, columns )
    message ||= default_error_message_for_violation( violation_type, columns )
  end

  def add_errors_for_violation( violation_type, columns )
    columns = [columns].flatten.compact
    message = error_message_for_violation( violation_type, columns )

    if columns.blank?
      self.errors.add_to_base( message )
    else
      self.errors.add( columns.first, message )
    end
  end

  def index_for_record_not_unique(exception) #:nodoc:
    case exception.message
      when /Duplicate entry.*for key (\d+)/
        index_position = $1.to_i
        # minus two b/c mysql message is one-based + rails excludes primary key index from indexes list
        ActiveRecord::Base.connection.indexes(self.class.table_name)[index_position - 2]
      when /Duplicate entry.*for key '(\w+)'/
        index_name = $1
        ActiveRecord::Base.connection.indexes(self.class.table_name).detect { |i| i.name == index_name }
    end
  end
  
  
  # Add a duplicate error message to errors based on the exception
  def add_unique_key_error( exception, columns = nil )
    columns ||= begin
      index = index_for_record_not_unique( exception )
      index.columns if index
    end
    add_errors_for_violation( :unique_key, columns )
  end

  # Add a foreign key error message to errors based on the exception
  def add_foreign_key_error(exception, foreign_key=nil)
    foreign_key ||= foreign_key_from_error_message( exception )
    add_errors_for_violation( :foreign_key, foreign_key )
  end

  # Return the foreign key name from the foreign key exception
  def foreign_key_from_error_message(exception)
    if (match = exception.to_s.match(/^Mysql::Error.*foreign key constraint fails.*FOREIGN KEY\s*\(`?([\w_]*)`?\)/))
      return match[1].dup
    end
  end

  # If +exception+ is a unique key violation or a foreign key error,
  # excute the block if it exists. If not and a record exists, add the
  # appropriate error messages. Reraise any exceptions that are not data integrity violation errors
  # Sometimes better to use +execute_with_data_integrity_check+ block
  #
  # +exception+ - Exception thrown from save (insert or update)
  # +record+ - The activerecord object to add errors
  #
  # ===Example
  #
  # def save_safe
  #   record = self
  #   save
  # rescue ActiveRecord::StatementInvalid => exception
  #   handle_data_integrity_error(exception, record)
  # end
  def handle_data_integrity_error(exception, record=nil, &block)
    @duplicate_exception = exception if exception.to_s =~ /^Mysql::Error: Duplicate entry/
    @foreign_key_exception = exception if exception.to_s =~ /^Mysql::Error.*foreign key constraint fails /

    if @duplicate_exception || @foreign_key_exception
      if block
        yield
      elsif record
        record.add_unique_key_error(exception)   if @duplicate_exception
        record.add_foreign_key_error(exception)  if @foreign_key_exception
        record
      end
    else
      raise exception
    end
  end

  # Executes the block and traps data integrity violations
  # Populates the +record+ errors objects with an appropriate message if such violation occurs
  #
  # ===Example
  #  def save_safe
  #   execute_with_data_integrity_check(self) { save }
  #  end
  def execute_with_data_integrity_check(record = nil, &block)
    @duplicate_exception = nil
    @foreign_key_exception = nil
    yield record
    true
  rescue ActiveRecord::StatementInvalid => exception
    handle_data_integrity_error(exception, record)
    return false
  end

  # do a create or update with data integrity check
  def create_or_update_with_data_integrity_check(options={})
    execute_with_data_integrity_check(self) do
      return create_or_update_without_data_integrity_check
    end
  end

  # save! with data integrity check
  # RecordNotSaved will be thrown by save! before converting to the standard
  # validation error ActiveRecord::RecordInvalid
  def save_with_data_integrity_check!(*args)
    save_without_data_integrity_check!(*args)
  rescue ActiveRecord::RecordNotSaved => e
    raise ActiveRecord::RecordInvalid.new(self) if @duplicate_exception||@foreign_key_exception
    raise e
  end
end

ActiveRecord::Base.send :include, ActiveRecord::RailsDevsForDataIntegrity

