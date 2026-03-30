using MediatR;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.PaymentQuery
{
    public class GetPaymentsByDocumentIdQuery : IRequest<IEnumerable<PaymentDto>>
    {
        public int DocumentId { get; set; }
        public int CompanyId { get; set; }

        public GetPaymentsByDocumentIdQuery(int documentId, int companyId)
        {
            DocumentId = documentId;
            CompanyId = companyId;
        }

        public class GetPaymentsByDocumentIdQueryHandler : IRequestHandler<GetPaymentsByDocumentIdQuery, IEnumerable<PaymentDto>>
        {
            private readonly PaymentRepository _repository;

            public GetPaymentsByDocumentIdQueryHandler(PaymentRepository repository)
            {
                _repository = repository;
            }

            public async Task<IEnumerable<PaymentDto>> Handle(GetPaymentsByDocumentIdQuery request, CancellationToken cancellationToken)
            {
                var payments = await _repository.GetByDocumentIdAsync(request.DocumentId, request.CompanyId);
                return payments.Select(MapperPayment.MapToPaymentDto);
            }
        }
    }
}