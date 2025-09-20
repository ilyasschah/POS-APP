// FILE: Products.Api.Domain\LoyaltyCard.cs

using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Products.Api.Domain;

[Table("LoyaltyCard")]
public class LoyaltyCard
{
    [Key]
    public int Id { get; private set; }
    public int CustomerId { get; private set; }
    public string? CardNumber { get; private set; }

    [ForeignKey(nameof(CustomerId))]
    public virtual Customer Customer { get; private set; }

    // Private constructor for the static Create method
    private LoyaltyCard(int customerId, string? cardNumber)
    {
        CustomerId = customerId;
        CardNumber = cardNumber;
    }
    
    // Public parameterless constructor for EF Core
    public LoyaltyCard() { }

    public static LoyaltyCard Create(int customerId, string? cardNumber)
    {
        if (customerId <= 0)
            throw new ArgumentException("CustomerId must be valid.", nameof(customerId));

        return new LoyaltyCard(customerId, cardNumber);
    }

    public void Update(string? cardNumber)
    {
        CardNumber = cardNumber;
    }
}
