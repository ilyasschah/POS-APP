// FILE: Products.Api.Domain\LoyaltyCard.cs

using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain;

[Table("LoyaltyCard")]
public class LoyaltyCard : ISyncableEntity
{
    [Key]
    public int Id { get; private set; }
    public int CompanyId { get; set; }
    public int CustomerId { get; private set; }
    public string? CardNumber { get; private set; }

    // Fully settable — the tablet is the source of truth for points.
    public decimal Points { get; set; }

    // Auto-stamped by AppDbContext on every INSERT/UPDATE; never set manually.
    public DateTime LastModified { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(CustomerId))]
    public virtual Customer? Customer { get; private set; }

    private LoyaltyCard(int customerId, string? cardNumber)
    {
        CustomerId = customerId;
        CardNumber = cardNumber;
    }

    // Public parameterless constructor for EF Core
    public LoyaltyCard() { }

    public static LoyaltyCard Create(int companyId, int customerId, string? cardNumber, decimal points = 0)
    {
        if (customerId <= 0)
            throw new ArgumentException("CustomerId must be valid.", nameof(customerId));

        return new LoyaltyCard(customerId, cardNumber)
        {
            CompanyId = companyId,
            Points = points
        };
    }

    public void Update(string? cardNumber)
    {
        CardNumber = cardNumber;
    }

    // Overwrites sync-able fields with the tablet's authoritative values.
    public void SyncFrom(string? cardNumber, decimal points)
    {
        CardNumber = cardNumber;
        Points = points;
    }
}
