using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.PaymentQuery
{
    public class GetPaymentsByDocumentIdQuery : IRequest<List<PaymentDto>>
    {
        public int DocumentId { get; set; }

        public class GetPaymentsByDocumentIdQueryHandler : IRequestHandler<GetPaymentsByDocumentIdQuery, List<PaymentDto>>
        {
            private readonly PaymentRepository _repository;

            public GetPaymentsByDocumentIdQueryHandler(PaymentRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PaymentDto>> Handle(GetPaymentsByDocumentIdQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetByDocumentIdAsync(request.DocumentId);
                return entities.Select(MapperPayment.MapToPaymentDto).ToList();
            }
        }
    }
}