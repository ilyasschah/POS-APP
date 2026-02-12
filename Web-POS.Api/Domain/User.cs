using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Runtime.CompilerServices;

namespace Products.Api.Domain;

[Table("User")]
public class User
{
    [Key]
    public int Id { get; private set; }
    public int CompanyId { get; set; }
    public string? FirstName { get; private set; }
    public string? LastName { get; private set; }
    public string? Username { get; private set; }
    public string Password { get; private set; }
    public int AccessLevel { get; private set; }
    public bool IsEnabled { get; private set; }
    public string? Email { get; private set; }

    public User() { }

    private User(string username, string password, int companyId)
    {
        Username = username;
        Password = password;
        IsEnabled = true;
        AccessLevel = 1;
        CompanyId = companyId;
    }

    public static User Create(string username, string password, int companyId)
    {
        return new User(username, password, companyId);
    }

    public void Update(string? firstName, string? lastName, string? username, int accessLevel, bool isEnabled, string? email, int companyId)
    {
        if (int.IsNegative(companyId))
            throw new ArgumentException("Username is required.", nameof(companyId));

        FirstName = firstName;
        LastName = lastName;
        Username = username;
        AccessLevel = accessLevel;
        IsEnabled = isEnabled;
        Email = email;
        CompanyId = companyId;
    }

    public void ChangePassword(string newPassword, int companyId)
    {
        if (string.IsNullOrWhiteSpace(newPassword))
            throw new ArgumentException("New password is required.", nameof(newPassword));

        Password = newPassword;
        CompanyId = companyId;
    }
}
