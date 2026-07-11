org = Company.find_or_create_by!(name: "Demo Company")
user = User.find_or_initialize_by(email: "admin@example.com")
user.assign_attributes(
  company: org,
  name: "Admin User",
  password: "password123",
  role: :admin
)
user.save!
org.company_memberships.find_or_create_by!(user: user) { |membership| membership.role = "admin" }
contact = org.contacts.find_or_create_by!(email: "client@example.com") { |c| c.name = "Client Contact" }
loan = org.loans.find_or_create_by!(title: "Demo Document Request", contact: contact, created_by: user) do |i|
  i.message = "Please upload the requested documents."
  i.due_at = 7.days.from_now
end
loan.request_items.find_or_create_by!(title: "Driver License") { |r| r.kind = :document }
loan.request_items.find_or_create_by!(title: "Bank Statement") { |r| r.kind = :document }
puts "Seeded demo org, user admin@example.com / password123"
