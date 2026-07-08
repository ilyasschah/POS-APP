using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PaymentQuery
{
    public class GetPaymentByIdQuery : IRequest<PaymentDto?>
    {
        public int Id { get; set; }

        public class GetPaymentByIdQueryHandler : IRequestHandler<GetPaymentByIdQuery, PaymentDto?>
        {
            private readonly PaymentRepository _repository;

            public GetPaymentByIdQueryHandler(PaymentRepository repository)
            {
                _repository = repository;
            }

            public async Task<PaymentDto?> Handle(GetPaymentByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperPayment.MapToPaymentDto(entity);
            }
        }
    }
}