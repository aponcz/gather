org = Company.find_or_create_by!(name: "Demo Company")
user = org.users.find_or_create_by!(email: "admin@example.com") do |u|
  u.name = "Admin User"
  u.password = "password123"
  u.role = :admin
end
contact = org.contacts.find_or_create_by!(email: "client@example.com") { |c| c.name = "Client Contact" }
invite = org.invites.find_or_create_by!(title: "Demo Document Request", contact: contact, created_by: user) do |i|
  i.message = "Please upload the requested documents."
  i.due_at = 7.days.from_now
end
invite.request_items.find_or_create_by!(title: "Driver License") { |r| r.kind = :document }
invite.request_items.find_or_create_by!(title: "Bank Statement") { |r| r.kind = :document }
puts "Seeded demo org, user admin@example.com / password123"
