using Products.Api.Domain;
using Products.Api.Repository;
using System.Drawing;
using static System.Net.Mime.MediaTypeNames;

namespace Products.Api.Services
{
    public class ProductGroupService
    {
        public ProductGroupRepository _productGroupRepository;

        public ProductGroupService (ProductGroupRepository productGroupRepository)
        {
            _productGroupRepository = productGroupRepository;
        }
        public async Task<bool> Create(string productgroupname, int? parentgroupid, string color, byte[]? image, int rank)
        {
            var pgexist = _productGroupRepository.Exist(productgroupname);
            if (pgexist == true)
                throw new InvalidOperationException($"A product group with the name '{productgroupname}' already exists.");
            var newproductGroup = ProductGroup.Create(productgroupname, parentgroupid , color,  image, rank);
            await _productGroupRepository.Add(newproductGroup);
            return true;
        }
    }
}
