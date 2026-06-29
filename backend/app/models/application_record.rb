class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def self.pg_json_serialize scope, fields, mapped_fields={}, json_root: scope.table_name, meta: {}
    table_name = scope.table_name

    all_fields = fields.map { |f| [f.to_s, "#{table_name}.#{f}"]}.to_h
                       .merge(mapped_fields.stringify_keys)

    args = all_fields.map do |field_key,field_value|
      if defined_enums.keys.include?(field_key.to_s)
        replacements = defined_enums[field_key.to_s].map do |enum_k,enum_v|
          "WHEN #{table_name}.#{field_key}=#{enum_v} THEN '#{enum_k}'"
        end.join(' ')
        ["'#{field_key}'","CASE #{replacements} ELSE '' END"]
      else
        ["'#{field_key}'", field_value]
      end
    end.flatten.join(',')

    r = scope.select("json_agg(json_build_object(#{args}))::TEXT AS json_str")&.to_a&.first || {}
    meta_str = meta.present? ? ",\"meta\": #{meta.to_json}" : ''
    "{\"#{json_root}\": #{r.json_str || '[]'}#{meta_str}}"
  end
end