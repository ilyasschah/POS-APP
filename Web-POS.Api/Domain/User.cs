using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain;

[Table("User")]
public class User
{
    [Key]
    public int Id { get;  set; }
    public int CompanyId { get; set; }
    public string? FirstName { get;  set; }
    public string? LastName { get;  set; }
    public string? Username { get;  set; }
    [Required]
    public string Password { get;  set; }
    public int AccessLevel { get;  set; }
    public bool IsEnabled { get;  set; }
    public string? Email { get;  set; }
    [ForeignKey(nameof(CompanyId))]
    public virtual Company Company { get; private set; }

    private User( int companyId,string? firstName, string? lastName, string? username, string password,int accessLevel, bool isEnabled, string? email)
    {
        if (companyId <= 0)
            throw new ArgumentException("Invalid CompanyId", nameof(companyId));
        if (string.IsNullOrWhiteSpace(username))
            throw new ArgumentException("Username cannot be empty", nameof(username));
        if (string.IsNullOrWhiteSpace(password))
            throw new ArgumentException("Password cannot be empty", nameof(password));
        CompanyId = companyId;
        FirstName = firstName;
        LastName = lastName;
        Username = username;
        Password = password;
        AccessLevel = accessLevel;
        IsEnabled = isEnabled;
        Email = email;
    }
    public User() { }
    public static User Create(int companyId, string? firstName, string? lastName, string? username, string password, int accessLevel, bool isEnabled, string? email)
    {
        return new User(companyId, firstName, lastName, username, password, accessLevel, isEnabled, email);
    }

    public void Update(string? firstName, string? lastName, string? username, int accessLevel, bool isEnabled, string? email)
    {
        Username = username;
        FirstName = firstName;
        LastName = lastName;
        AccessLevel = accessLevel;
        IsEnabled = isEnabled;
        Email = email;
    }

    public void ChangePassword(string newPassword, int companyId)
    {
        if (string.IsNullOrWhiteSpace(newPassword))
            throw new ArgumentException("New password is required.", nameof(newPassword));
        Password = newPassword;
        CompanyId = companyId;
    }
}
