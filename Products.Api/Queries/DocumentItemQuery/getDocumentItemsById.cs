using MediatR;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.DocumentItemQuery
{
    public class GetDocumentItemsByIdQuery : IRequest<DocumentItemDto>
    {
        public int Id { get; set; }
        public GetDocumentItemsByIdQuery(int id)
        {
            Id = id;
        }
    }
    public class GetDocumentItemsByIdQueryHandler : IRequestHandler<GetDocumentItemsByIdQuery,DocumentItemDto>
    {
        private readonly DocumentItemRepository _documentItemRepository;
        public GetDocumentItemsByIdQueryHandler(DocumentItemRepository documentItemRepository)
        {
            _documentItemRepository = documentItemRepository;
        }
        public async Task<DocumentItemDto> Handle(GetDocumentItemsByIdQuery request,CancellationToken cancellationToken)
        {
            var documentitem = await _documentItemRepository.GetDocumentItemByIdAsync(request.Id);
            return new DocumentItemDto
            {
                Id = documentitem.Id,
                DocumentNumber = documentitem.Document.Number,
                ProductName = documentitem.Product.Name,
                Quantity = documentitem.Quantity,
                Price = documentitem.Price,
                Total = documentitem.Total,
            };
        }
    }

}
