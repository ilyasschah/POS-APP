using Products.Api.Domain;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Documents.Api.Domain
{
    [Table("DocumentItem")]
    public class DocumentItem
    {
        [Key]
        public int Id { get; set; }
        public int DocumentId { get; set; }
        public int ProductId { get; set; }
        public Decimal Quantity { get; set; }
        public Decimal  ExpectedQuantity { get; set; }
        public Decimal  PriceBeforeTax { get; set; }
        public Decimal  Price   { get; set; }
        public Decimal Discount  { get; set; }
        public int  DiscountType  { get; set; }
        public Decimal  ProductCost { get; set; }
        public Decimal  PriceBeforeTaxAfterDiscount  { get; set; }
        public Decimal  PriceAfterDiscount    { get; set; }
        public Decimal  Total   { get; set; }
        public Decimal  TotalAfterDocumentDiscount   { get; set; }
        public bool  DiscountApplyRule  { get; set; }
        //public DateTime DateCreated { get; set; }
        //public DateTime DateUpdated { get; set; }
        [ForeignKey(nameof(ProductId))]
        public virtual Product Product { get; set; }
        [ForeignKey(nameof(DocumentId))]
        public virtual Document Document { get; set; }
        private DocumentItem (int documentId, int productId, decimal quantity, decimal priceBeforeTax, decimal price, decimal discount, int discountType, decimal productCost, decimal priceBeforeTaxAfterDiscount, decimal priceAfterDiscount, decimal total, decimal totalAfterDocumentDiscount, bool discountApplyRule)
        {
            DocumentId = documentId;
            ProductId = productId;
            Quantity = quantity;
            PriceBeforeTax = priceBeforeTax;
            Price = price;
            Discount = discount;
            DiscountType = discountType;
            ProductCost = productCost;
            PriceBeforeTaxAfterDiscount = priceBeforeTaxAfterDiscount;
            PriceAfterDiscount = priceAfterDiscount;
            Total = total;
            TotalAfterDocumentDiscount = totalAfterDocumentDiscount;
            DiscountApplyRule = discountApplyRule;
        }
        public DocumentItem() { }
        public static DocumentItem Create(
            int documentId, 
            int productId, 
            decimal quantity, 
            decimal priceBeforeTax,
            decimal price, 
            decimal discount, 
            int discountType, 
            decimal productCost, 
            decimal priceBeforeTaxAfterDiscount, 
            decimal priceAfterDiscount, 
            decimal total, 
            decimal totalAfterDocumentDiscount, 
            bool discountApplyRule)
        {
            return new DocumentItem(documentId, productId, quantity, priceBeforeTax, price, discount, discountType, productCost, priceBeforeTaxAfterDiscount, priceAfterDiscount, total, totalAfterDocumentDiscount, discountApplyRule);
        }
        public void UpdateQuantity(decimal newquantity)
        {
            Quantity = newquantity;
            //DateUpdated = DateTime.UtcNow;
        }
    }
}
