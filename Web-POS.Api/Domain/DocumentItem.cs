using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("DocumentItem")]
    public class DocumentItem
    {
        [Key]
        public int Id { get; private set; }
        public int CompanyId { get; private set; }
        public int DocumentId { get; private set; }
        public int ProductId { get; private set; }
        public decimal Quantity { get; private set; }
        public decimal ExpectedQuantity { get; private set; }
        public decimal PriceBeforeTax { get; private set; }
        public decimal Price { get; private set; }
        public decimal Discount { get; private set; }
        public int DiscountType { get; private set; }
        public decimal ProductCost { get; private set; }
        public decimal PriceBeforeTaxAfterDiscount { get; private set; }
        public decimal PriceAfterDiscount { get; private set; }
        public decimal Total { get; private set; }
        public decimal TotalAfterDocumentDiscount { get; private set; }
        public bool DiscountApplyRule { get; private set; }

        [ForeignKey(nameof(ProductId))]
        public virtual Product? Product { get; private set; }

        [ForeignKey(nameof(DocumentId))]
        public virtual Document? Document { get; private set; }

        private DocumentItem(
            int companyId,
            int documentId,
            int productId,
            decimal quantity,
            decimal expectedQuantity,
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
            CompanyId = companyId;
            DocumentId = documentId;
            ProductId = productId;
            Quantity = quantity;
            ExpectedQuantity = expectedQuantity;
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
            int companyId, int documentId, int productId, decimal quantity, decimal expectedQuantity,
            decimal priceBeforeTax, decimal price, decimal discount, int discountType,
            decimal productCost, decimal priceBeforeTaxAfterDiscount, decimal priceAfterDiscount,
            decimal total, decimal totalAfterDocumentDiscount, bool discountApplyRule)
        {
            return new DocumentItem(
                companyId, documentId, productId, quantity, expectedQuantity, priceBeforeTax,
                price, discount, discountType, productCost, priceBeforeTaxAfterDiscount,
                priceAfterDiscount, total, totalAfterDocumentDiscount, discountApplyRule);
        }

        public void UpdateDetails(
            int documentId, int productId, decimal quantity, decimal expectedQuantity,
            decimal priceBeforeTax, decimal price, decimal discount, int discountType,
            decimal productCost, decimal priceBeforeTaxAfterDiscount, decimal priceAfterDiscount,
            decimal total, decimal totalAfterDocumentDiscount, bool discountApplyRule)
        {
            if (DocumentId != documentId)
            {
                DocumentId = documentId;
                Document = null;
            }

            if (ProductId != productId)
            {
                ProductId = productId;
                Product = null;
            }

            Quantity = quantity;
            ExpectedQuantity = expectedQuantity;
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
    }
}