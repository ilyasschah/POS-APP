using Documents.Api.Helpers;
using Documents.Api.Models;
using Documents.Api.Repository;
using MediatR;

namespace Documents.Api.Queries.PaymentQuery
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