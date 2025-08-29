using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.VoidReasonQuery
{
    public class GetVoidReasonByIdQuery : IRequest<VoidReasonDto?>
    {
        public int Id { get; set; }

        public class GetVoidReasonByIdQueryHandler : IRequestHandler<GetVoidReasonByIdQuery, VoidReasonDto?>
        {
            private readonly VoidReasonRepository _repository;

            public GetVoidReasonByIdQueryHandler(VoidReasonRepository repository)
            {
                _repository = repository;
            }

            public async Task<VoidReasonDto?> Handle(GetVoidReasonByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperVoidReason.MapToVoidReasonDto(entity);
            }
        }
    }
}