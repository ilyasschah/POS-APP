using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PaymentQuery
{
    public class GetAllPaymentsQuery : IRequest<List<PaymentDto>>
    {
        public class GetAllPaymentsQueryHandler : IRequestHandler<GetAllPaymentsQuery, List<PaymentDto>>
        {
            private readonly PaymentRepository _repository;

            public GetAllPaymentsQueryHandler(PaymentRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PaymentDto>> Handle(GetAllPaymentsQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync();
                return entities.Select(MapperPayment.MapToPaymentDto).ToList();
            }
        }
    }
}