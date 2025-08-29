using Documents.Api.Helpers;
using Documents.Api.Models;
using Documents.Api.Repository;
using MediatR;

namespace Documents.Api.Queries.DocumentQuery
{
    public class GetDocumentByIdQuery(int id) : IRequest<DocumentDto?>
    {
        public int Id { get; set; } = id;

        public class GetDocumentByIdQueryHandler : IRequestHandler<GetDocumentByIdQuery, DocumentDto?>
        {
            private readonly DocumentRepository _repository;

            public GetDocumentByIdQueryHandler(DocumentRepository repository)
            {
                _repository = repository;
            }

            public async Task<DocumentDto?> Handle(GetDocumentByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                if (entity == null || entity.Id == 0)
                {
                    return null;
                }
                return new DocumentDto
                {
                    Id = entity.Id,
                    Number = entity.Number,
                    Date = entity.Date,
                    UserId = entity.UserId,
                    DocumentTypeId = entity.DocumentTypeId,
                    WarehouseId = entity.WarehouseId,
                    Total = entity.Total
                };
            }
        }
    }
}