using Products.Api.Domain;
using Products.Api.Repository;

namespace Products.Api.Services
{
    public class ProductService(ProductRepository productRepository)
    {
        public ProductRepository _productRepository = productRepository;

        public async Task<bool> Create(
            string name,
            string code,
            int? plu,
            string measurementunit,
            decimal price,
            bool istaxinclusiveprice,
            bool ispricechangeallowed,
            bool isservice,
            bool isusingdefaultquantity,
            bool isenabled,
            string description,
            decimal cost,
            decimal markup,
            byte[] image,
            string color,
            int agerestriction,
            decimal lastpurchaseprice,
            int rank,
            int productGroupId,
            int currencyId,
            DateTime datecreated,
            DateTime dateupdated)
        {
            var cexist = _productRepository.Exist(name);
            if (cexist == true)
                throw new InvalidOperationException($"A product with the name '{name}' already exists.");
            var newproduct = Product.Create(
                name,
                code,
                plu,
                measurementunit,
                price,
                istaxinclusiveprice,
                ispricechangeallowed,
                isservice,
                isusingdefaultquantity,
                isenabled,
                description,
                cost,
                markup,
                image,
                color,
                agerestriction,
                lastpurchaseprice,
                rank,
                productGroupId,
                currencyId,
                datecreated,
                dateupdated
            );
            await _productRepository.Add(newproduct);
            return true;
        }
    }
}
