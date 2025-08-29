using Products.Api.Domain;
using Products.Api.Repository;
namespace Products.Api.Services
{
    public class ProductCommentsService
    {
        public ProductCommentRepository _productCommentsRepository;

        public ProductCommentsService(ProductCommentRepository productCommentsRepository)
        {
            _productCommentsRepository = productCommentsRepository;
        }
        public async Task<bool> Create(string comment , int productid)
        {
            var pcexists = _productCommentsRepository.Exists(comment);
            if (pcexists == true)
                throw new InvalidOperationException($"A comment with the text '{comment}' already exists.");
            var productComment = ProductComment.Create(comment, productid);
            await _productCommentsRepository.Add(productComment);
            return true;
        }
    }
}
