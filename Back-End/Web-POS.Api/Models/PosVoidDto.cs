namespace Api.Models;

public class PosVoidDto
{
    public int Id { get; set; }
    public int CompanyId { get; set; }
    public string OrderNumber { get; set; } = string.Empty;
    public string UserName { get; set; } = string.Empty;
    public string ProductName { get; set; } = string.Empty;
    public decimal Quantity { get; set; }
    public decimal Price { get; set; }
    public decimal Discount { get; set; }
    public int DiscountType { get; set; }
    public decimal Total { get; set; }
    public bool IsConfirmed { get; set; }
    public string? Reason { get; set; }
    public string? VoidedByName { get; set; }
    public DateTime DateCreated { get; set; }
    public DateTime DateVoided { get; set; }
}

public class CreatePosVoidRequest
{
    public required int CompanyId { get; set; }
    public required string OrderNumber { get; set; }
    public int? UserId { get; set; }
    public required string UserName { get; set; }
    public int? ProductId { get; set; }
    public required string ProductName { get; set; }
    public required int RoundNumber { get; set; }
    public required decimal Quantity { get; set; }
    public required decimal Price { get; set; }
    public decimal Discount { get; set; } = 0;
    public int DiscountType { get; set; } = 0;
    public required decimal Total { get; set; }
    public string? Reason { get; set; }
    public string? Bundle { get; set; }
    public int? VoidedById { get; set; }
    public string? VoidedByName { get; set; }
}

public class UpdatePosVoidRequest
{
    public required int Id { get; set; }
    public required int VoidedById { get; set; }
    public required int VoidedBy { get; set; }
    public required string VoidedByName { get; set; }
}

public class GetPosVoidsByDateRangeRequest
{
    public required int CompanyId { get; set; }
    public required DateTime StartDate { get; set; }
    public required DateTime EndDate { get; set; }
    public int? UserId { get; set; }
    public int? ProductId { get; set; }
}
