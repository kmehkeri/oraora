module Oraora
  module Awareness
    Entry = Struct.new(:key, :object_types, :map, :sql)

    ENRICH_MAP = [
      # Column
      Entry.new(:column, nil,                                     %w(SELECT ;),         'SELECT $column FROM $object'),
      *%w(PARTITION WHERE CONNECT GROUP MODEL UNION INTERSECT MINUS ORDER).collect do |keyword|
        Entry.new(:column, nil,                                     [keyword],            "SELECT $column FROM $object #{keyword}")
      end,
      Entry.new(:column, nil,                                     %w(SET),              'UPDATE $object SET $column ='),
      Entry.new(:column, 'TABLE',                                 %w(DROP),             'ALTER TABLE $object DROP COLUMN $column'),
      Entry.new(:column, 'TABLE',                                 %w(RENAME),           'ALTER TABLE $table RENAME COLUMN $column TO'),

      # Table
      Entry.new(:object, 'TABLE',                                 %w(DROP ;),           'DROP TABLE $object'),
      Entry.new(:object, 'TABLE',                                 %w(DROP CASCADE),     'DROP TABLE $object CASCADE'),
      Entry.new(:object, 'TABLE',                                 %w(DROP PURGE),       'DROP TABLE $object PURGE'),
      Entry.new(:object, 'TABLE',                                 %w(TRUNCATE),         'TRUNCATE TABLE $object'),
      Entry.new(:object, 'TABLE',                                 %w(DROP PARTITION),   'ALTER TABLE $object DROP PARTITION'),
      *%w(ADD MODIFY RENAME PARALLEL NOPARALLEL ENABLE DISABLE CACHE NOCACHE READ REKEY PCTFREE PCTUSED INITRANS COMPRESS NOCOMPRESS SHRINK MERGE SPLIT).collect do |keyword|
        Entry.new(:object, 'TABLE',                                 [keyword],            "ALTER TABLE $object #{keyword}")
      end,

      # View
      Entry.new(:object, 'VIEW',                                  %w(DROP),             'DROP VIEW $object'),
      Entry.new(:object, 'VIEW',                                  %w(RENAME),           'RENAME $object'),
      Entry.new(:object, 'VIEW',                                  %w(COMPILE),          'ALTER VIEW $object COMPILE'),

      # Mview
      Entry.new(:object, 'MATERIALIZED VIEW',                     %w(DROP),             'DROP MATERIALIZED VIEW $object'),

      # Relation
      Entry.new(:object, ['TABLE', 'VIEW', 'MATERIALIZED VIEW'],  %w(SELECT ;),         'SELECT * FROM $object'),
      Entry.new(:object, ['TABLE', 'VIEW', 'MATERIALIZED VIEW'],  %w(COUNT ),           'SELECT count(*) FROM $object'),
      *%w(PARTITION WHERE CONNECT GROUP MODEL UNION INTERSECT MINUS ORDER).collect do |keyword|
        Entry.new(:object, ['TABLE', 'VIEW', 'MATERIALIZED VIEW'],  [keyword],            "SELECT * FROM $object #{keyword}")
      end,
      Entry.new(:object, ['TABLE', 'VIEW', 'MATERIALIZED VIEW'],  %w(SET),              'UPDATE  $object SET'),
      Entry.new(:object, ['TABLE', 'VIEW', 'MATERIALIZED VIEW'],  %w(DELETE ;),         'DELETE FROM $object'),
      Entry.new(:object, ['TABLE', 'VIEW', 'MATERIALIZED VIEW'],  %w(DELETE WHERE),     'DELETE FROM $object WHERE'),
      Entry.new(:object, ['TABLE', 'VIEW', 'MATERIALIZED VIEW'],  %w(INSERT VALUES),    'INSERT INTO $object VALUES'),
      Entry.new(:object, ['TABLE', 'VIEW', 'MATERIALIZED VIEW'],  %w(INSERT SELECT),    'INSERT INTO $object SELECT'),

      # Schema
      *%w(IDENTIFIED PROFILE ACCOUNT QUOTA DEFAULT TEMPORARY).collect do |keyword|
        Entry.new(:schema, nil,                                     [keyword],            "ALTER USER $schema #{keyword}")
      end
    ]

    def self.enrich(sql, context)
      tokens = []
      map = []
      (sql + ';').scan(/(?:\w+|\/\*.*?\*\/|--.*?\n|;|\s+)/mi) do |token|
        tokens << token
        if token =~ /^(\/\*.*?\*\/|--.*?\n|\s+)$/mi
          next
        end
        map << token.upcase
        #puts "[AWARENESS] #{token}, map: #{map}"
        match = ENRICH_MAP.detect do |entry|
          context.send(entry.key) && (!entry.object_types || [*entry.object_types].include?(context.object_type)) && map == entry.map
        end

        if match
          #puts "[AWARENESS] Map match: #{match.sql}"
          sql =~ /^#{tokens.join.chomp(';')}(.*)$/mi
          last_part = $1
          first_part = eval '"' + match.sql.gsub(/\$(\w+)+/, '#{context.send(:\1)}') + '"'
          return first_part + last_part
        end

        break if tokens.length >= 2
      end
      sql
    end
  end
end