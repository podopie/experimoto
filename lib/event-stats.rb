
require 'date'
require 'openssl'
require 'thread'
require 'set'

require 'rubygems'
require 'json'
require 'rdbi'

module Experimoto
  module EventStats
    
    def self.table_creation_statements
      [('create table if not exists event_stats (' +
        ['eid char(22)',
         'group_name varchar(200)',
         'event_key varchar(200)',
         'stat_type varchar(200)',
         'value double',
        ].join(',') + ');')]
    end
    
    def self.index_creation_statements
      ['create unique index event_stats_ids on event_stats(eid, group_name, event_key, stat_type);']
    end
    
    def self.add_event_stat(db_handle, eid, group_name, event_key, stat_type, value = 1)
      # TODO: test and fix mysql stuff (i don't think this will work)
      mysql_sql = ('set transaction level serializable; begin transaction;' +
                   'insert into event_stats values (?,?,?,?,?) ' +
                   'on duplicate key update value = value + ?;' +
                   'commit;')
      sqlite_sql = ('insert or replace into event_stats values (?,?,?,?,' +
                    'coalesce((select value + ? from event_stats ' +
                    '          where eid = ? and group_name = ? and event_key = ? ' +
                    '            and stat_type = ?), ?));')
      mysql_args = [eid, group_name, event_key, stat_type, value, value]
      sqlite_args = [eid, group_name, event_key, stat_type, value,
                     eid, group_name, event_key, stat_type, value]
      case db_handle.class.to_s
      when /sqlite/i ; sql, args = sqlite_sql, sqlite_args
      when /mysql/i  ; sql, args = mysql_sql, mysql_args
      else           ; raise 'unknown database type!'
      end
      db_handle.prepare(sql) do |sth|
        sth.execute(args)
      end
    end
    
    def self.get_event_stat(db_handle, eid, group_name, event_key, stat_type)
      value = 0
      db_handle.prepare('select value from event_stats where eid = ? and group_name = ? and event_key = ? and stat_type = ?;') do |sth|
        sth.execute(eid, group_name, event_key, stat_type).each do |x|
          next if x.nil?
          value = x[0]
          break
        end
      end
      value
    end
    
  end
end
