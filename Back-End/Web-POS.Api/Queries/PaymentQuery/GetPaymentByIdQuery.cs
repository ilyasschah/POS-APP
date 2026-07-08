using MediatR;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.PaymentQuery
{
    public class GetPaymentByIdQuery : IRequest<PaymentDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public GetPaymentByIdQuery(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class GetPaymentByIdQueryHandler : IRequestHandler<GetPaymentByIdQuery, PaymentDto?>
        {
            private readonly PaymentRepository _repository;

            public GetPaymentByIdQueryHandler(PaymentRepository repository)
            {
                _repository = repository;
            }

            public async Task<PaymentDto?> Handle(GetPaymentByIdQuery request, CancellationToken cancellationToken)
            {
                var payment = await _repository.GetByIdAsync(request.Id, request.CompanyId);
                return payment == null ? null : MapperPayment.MapToPaymentDto(payment);
            }
        }
    }
}