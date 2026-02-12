using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PaymentTypeQuery
{
    public class GetPaymentTypeByNameQuery : IRequest<PaymentTypeDto?>
    {
        public string Name { get; set; }
        public int CompanyId { get; set; }

        public class GetPaymentTypeByNameQueryHandler : IRequestHandler<GetPaymentTypeByNameQuery, PaymentTypeDto?>
        {
            private readonly PaymentTypeRepository _repository;

            public GetPaymentTypeByNameQueryHandler(PaymentTypeRepository repository)
            {
                _repository = repository;
            }

            public async Task<PaymentTypeDto?> Handle(GetPaymentTypeByNameQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByNameAsync(request.Name, request.CompanyId);
                return entity == null ? null : MapperPaymentType.MapToPaymentTypeDto(entity);
            }
        }
    }
}