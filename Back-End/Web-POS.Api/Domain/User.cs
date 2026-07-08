using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("User")]
    public class User : ISyncableEntity
    {
        [Key]
        public int Id { get; private set; }

        public int CompanyId { get; private set; }

        // Public set required by ISyncableEntity — stamped by DbContext, never by call sites.
        public DateTime LastModified { get; set; } = DateTime.UtcNow;
        public string? FirstName { get; private set; }
        public string? LastName { get; private set; }
        [Required]
        public string? Username { get; private set; }
        [Required]
        public string Password { get; private set; }
        public int AccessLevel { get; private set; }
        public bool IsEnabled { get; private set; }
        public string? Email { get; private set; }

        [ForeignKey(nameof(CompanyId))]
        public virtual Company Company { get; private set; }

        public User() { }

        private User(int companyId, string? firstName, string? lastName, string username, string password, int accessLevel, bool isEnabled, string? email)
        {
            if (companyId <= 0) throw new ArgumentException("Invalid CompanyId", nameof(companyId));
            if (string.IsNullOrWhiteSpace(username)) throw new ArgumentException("Username cannot be empty", nameof(username));
            if (string.IsNullOrWhiteSpace(password)) throw new ArgumentException("Password cannot be empty", nameof(password));

            CompanyId = companyId;
            FirstName = firstName;
            LastName = lastName;
            Username = username;
            Password = password;
            AccessLevel = accessLevel;
            IsEnabled = isEnabled;
            Email = email;
        }

        public static User Create(int companyId, string? firstName, string? lastName, string username, string password, int accessLevel, bool isEnabled, string? email)
        {
            return new User(companyId, firstName, lastName, username, password, accessLevel, isEnabled, email);
        }

        public void Update(string? firstName, string? lastName, string username, int accessLevel, bool isEnabled, string? email)
        {
            if (string.IsNullOrWhiteSpace(username)) throw new ArgumentException("Username cannot be empty", nameof(username));

            Username = username;
            FirstName = firstName;
            LastName = lastName;
            AccessLevel = accessLevel;
            IsEnabled = isEnabled;
            Email = email;
        }

        public void ChangePassword(string newPassword)
        {
            if (string.IsNullOrWhiteSpace(newPassword))
                throw new ArgumentException("New password is required.", nameof(newPassword));

            Password = newPassword;
        }
    }
}